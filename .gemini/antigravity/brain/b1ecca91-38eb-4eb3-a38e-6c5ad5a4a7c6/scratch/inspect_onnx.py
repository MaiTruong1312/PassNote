import onnx
model = onnx.load('d:/AndroidStudioProjects/PassNote/assets/model/arcface.onnx')
for input in model.graph.input:
    print(f"Input: {input.name}, Shape: {[dim.dim_value for dim in input.type.tensor_type.shape.dim]}")
for output in model.graph.output:
    print(f"Output: {output.name}, Shape: {[dim.dim_value for dim in output.type.tensor_type.shape.dim]}")
