# main.py
from fastapi import FastAPI, UploadFile, File
from deepface import DeepFace
import numpy as np
import cv2
import os

app = FastAPI()

@app.on_event("startup")
def load_models():
    print("Đang nạp Mô hình AI Facenet và MTCNN vào RAM trước để tăng tốc độ...")
    dummy_img = np.zeros((224, 224, 3), dtype=np.uint8)
    try:
        DeepFace.represent(img_path=dummy_img, model_name="Facenet", detector_backend="opencv", enforce_detection=False)
        print("Tải AI thành công! Sẵn sàng nhận diện vận tốc cao.")
    except Exception as e:
        print("Lỗi khởi tạo AI:", e)

@app.post("/extract-face")
async def extract_face(file: UploadFile = File(...)):
    try:
        # 1. Đọc file qua PIL để giữ chuẩn góc nghiêng EXIF (Bắt khuôn mặt thẳng đứng)
        contents = await file.read()
        from PIL import Image, ImageOps
        import io
        pil_img = Image.open(io.BytesIO(contents))
        pil_img = ImageOps.exif_transpose(pil_img) # Xoay chuẩn lại góc đứng
        
        # Chuyển đổi sang BGR cho OpenCV tùy thuộc vào có chứa dải Alpha (PNG) hay không
        img_np = np.array(pil_img)
        if len(img_np.shape) == 3 and img_np.shape[2] == 4:
            img_cv2 = cv2.cvtColor(img_np, cv2.COLOR_RGBA2BGR)
        else:
            img_cv2 = cv2.cvtColor(img_np, cv2.COLOR_RGB2BGR)

        # BẢO VỆ CHỐNG TREO MÁY: Nếu cố tình up ảnh gốc 4K, AI sẽ nội suy đến sập RAM. Ép ảnh bé lại!
        h, w = img_cv2.shape[:2]
        if max(h, w) > 800:
            scale = 800 / max(h, w)
            img_cv2 = cv2.resize(img_cv2, (int(w * scale), int(h * scale)))

        if img_cv2 is None:
            return {"success": False, "error": "Image decode failed on server"}

        # 2. Xử lý tốc độ ánh sáng (10ms) với OpenCV và thử 4 góc xoay thủ công nếu điện thoại lật ảnh gốc
        embeddings = None
        last_error = ""
        angles = [None, cv2.ROTATE_90_CLOCKWISE, cv2.ROTATE_180, cv2.ROTATE_90_COUNTERCLOCKWISE]
        
        for angle in angles:
            test_img = img_cv2
            if angle is not None:
                test_img = cv2.rotate(img_cv2, angle)
                
            try:
                embeddings = DeepFace.represent(
                    img_path=test_img,
                    model_name="Facenet",
                    detector_backend='opencv',
                    enforce_detection=True
                )
                break # Đã tìm thấy mặt! Dừng xoay.
            except Exception as e:
                last_error = str(e)
                continue
                
        if embeddings is None or len(embeddings) == 0:
            return {"success": False, "error": last_error}

        return {
            "success": True,
            "embedding": embeddings[0]['embedding'],
            "area": embeddings[0]['facial_area']
        }

    except Exception as e:
        return {"success": False, "error": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)