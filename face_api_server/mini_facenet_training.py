import tensorflow as tf
from tensorflow.keras import layers, models

"""
================================================================
MINI-FACENET BẢN THU NHỎ (DÀNH CHO ĐỒ ÁN MÔN TRÍ TUỆ NHÂN TẠO)
================================================================
Cốt lõi của Face Recognition là Mạng Song Sinh (Siamese Network) 
kết hợp với Hàm Mất Mát Bộ Ba (Triplet Loss).
"""

# 1. XÂY DỰNG MẠNG CNN RÚT TRÍCH ĐẶC TRƯNG (Feature Extractor)
# Nhận vào 1 bức ảnh (cắt gọn khuôn mặt cỡ 96x96 pixels)
# Trả ra 1 dãy gen (Vector) gồm 128 chữ số để trích xuất đặc điểm.
def build_base_network(input_shape=(96, 96, 3)):
    model = models.Sequential([
        # Các tầng Tích chập (ConvolutionLayer) tự học cách nhìn các đường nét: mắt, mũi, cằm
        layers.Conv2D(32, (3, 3), activation='relu', input_shape=input_shape),
        layers.MaxPooling2D((2, 2)),
        
        layers.Conv2D(64, (3, 3), activation='relu'),
        layers.MaxPooling2D((2, 2)),
        
        layers.Conv2D(128, (3, 3), activation='relu'),
        layers.MaxPooling2D((2, 2)),
        
        # Vuốt dẹp lại và chuyển đổi thành dãy gen Vector
        layers.Flatten(),
        layers.Dense(512, activation='relu'),
        layers.Dense(128, activation=None), # Đây là 128 Dimension Embedding (Hệt như DeepFace)
        
        # (Quan Trọng) Ép tất cả các chuỗi Vector lên 1 mặt cầu đơn vị (L2 Normalization)
        # Để dễ dàng tính khoảng cách Cosine Similarity bằng Toán Học.
        layers.Lambda(lambda x: tf.math.l2_normalize(x, axis=1)) 
    ])
    return model

# 2. HÀM MẤT MÁT BỘ BA (TRIPLET LOSS) - LINH HỒN CỦA FACENET
# Mạng AI học bằng cách nhìn 3 ảnh cùng lúc:
# 1. Anchor: Ảnh mốc (Mặt của bạn)
# 2. Positive: Ảnh cùng loại (Ảnh mặt của bạn nhưng chụp góc tối hơn/nghiêng hơn)
# 3. Negative: Ảnh khác loại (Mặt của người lạ)
# -> Nhiệm vụ: Kéo khoảng cách (Anchor-Positive) lại gần nhau, và đạp (Anchor-Negative) văng ra xa nhau!
def triplet_loss(y_true, y_pred, alpha=0.2):
    # Cắt 3 cụm vector từ Model trả về dể so sánh
    anchor, positive, negative = y_pred[:, 0:128], y_pred[:, 128:256], y_pred[:, 256:]
    
    # Khoảng cách giữa mặt thật (Anchor) và mặt người đó (Positive) -> Càng nhỏ càng tốt
    pos_dist = tf.reduce_sum(tf.square(anchor - positive), axis=-1)
    
    # Khoảng cách giữa mặt thật (Anchor) và mặt người lạ (Negative) -> Càng xa càng tốt
    neg_dist = tf.reduce_sum(tf.square(anchor - negative), axis=-1)
    
    # Tính Tổng Loss (Nếu người lạ bị đẩy ra xa hơn khoảng biên Alpha thì Loss = 0)
    basic_loss = pos_dist - neg_dist + alpha
    return tf.reduce_sum(tf.maximum(basic_loss, 0.0))

# 3. GHÉP MẠNG SONG SINH (SIAMESE NETWORK)
# Ghép 3 cái base_network (chia sẻ chung trọng số não bộ) để chấm điểm 3 tấm ảnh cùng một lúc!
def build_siamese_model(base_network):
    input_anchor = layers.Input(shape=(96, 96, 3), name='anchor')
    input_positive = layers.Input(shape=(96, 96, 3), name='positive')
    input_negative = layers.Input(shape=(96, 96, 3), name='negative')

    emb_a = base_network(input_anchor)
    emb_p = base_network(input_positive)
    emb_n = base_network(input_negative)

    # Nối 3 Mảng 128 số ghép lại thành 384 con số truyền về tay hàm TripletLoss để tính toán
    output = layers.Concatenate(axis=-1)([emb_a, emb_p, emb_n])
    
    return models.Model(inputs=[input_anchor, input_positive, input_negative], outputs=output)

if __name__ == "__main__":
    print("Đang khởi tạo Mạng Mini-FaceNet...")
    base_cnn = build_base_network()
    siamese_net = build_siamese_model(base_cnn)
    
    # Build Model với Optimizer Keras siêu tốc và hàm Triplet Loss tự viết ở trên
    siamese_net.compile(optimizer='adam', loss=triplet_loss)
    
    print("\n" + "="*50)
    print("AI MODEL ARCHITECTURE ĐÃ SẴN SÀNG!")
    siamese_net.summary()
    print("Bạn chỉ cần tạo 1 cái vòng for đọc ảnh thư mục để cung cấp (Anchor, Pos, Neg) là chạy .fit() được ngay!")
