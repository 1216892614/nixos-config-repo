#!/usr/bin/env python3
"""构建 CRX3 格式的 Chrome 扩展包。

用法: python3 build-crx3.py <extension_dir> <private_key.pem> <output.crx>

CRX3 格式:
  magic "Cr24" (4 bytes)
  version = 3  (uint32 LE)
  header_size  (uint32 LE)
  CrxFileHeader protobuf:
    sha256_with_rsa {
      public_key: DER-encoded public key
      signature:  RSA-SHA256 signature of (header_proto + zip)
    }
    signed_header_data: SignedData { crx_id = SHA256(public_key)[:16] }
"""
import struct
import subprocess
import sys
import tempfile
import zipfile
import os

def build_crx3(ext_dir, pem_path, out_path):
    # 1. 生成 ZIP
    zip_data = _zip_dir(ext_dir)

    # 2. 读取 PEM 密钥，提取 DER 公钥
    der_pub = subprocess.check_output(
        ["openssl", "rsa", "-pubout", "-outform", "DER", "-in", pem_path],
        stderr=subprocess.DEVNULL,
    )

    # 3. 构建 signed_header_data（包含 crx_id = 公钥 SHA256 前 16 字节）
    import hashlib
    crx_id = hashlib.sha256(der_pub).digest()[:16]
    signed_header_data = _proto_bytes(1, crx_id)  # SignedData { crx_id }
    to_sign = (
        b"CRX3 SignedData\x00"
        + struct.pack("<I", len(signed_header_data))
        + signed_header_data
        + zip_data
    )
    with tempfile.NamedTemporaryFile(suffix=".bin", delete=False) as tf:
        tf.write(to_sign)
        tf_path = tf.name
    try:
        sig = subprocess.check_output(
            ["openssl", "dgst", "-sha256", "-sign", pem_path, "-out", "/dev/stdout", tf_path],
            stderr=subprocess.DEVNULL,
        )
    finally:
        os.unlink(tf_path)

    # 4. 构建 protobuf（手动编码，无需 protobuf 库）
    #    CrxFileHeader:
    #      field 2 (AsymmetricKeyProof sha256_with_rsa): repeated
    #        field 1 (bytes public_key)
    #        field 2 (bytes signature)
    #      field 10000 (bytes signed_header_data)
    proof = _proto_bytes(1, der_pub) + _proto_bytes(2, sig)
    header_proto = _proto_bytes(2, proof) + _proto_bytes(10000, signed_header_data)

    # 5. 写 CRX3
    with open(out_path, "wb") as f:
        f.write(b"Cr24")                              # magic
        f.write(struct.pack("<I", 3))                  # version
        f.write(struct.pack("<I", len(header_proto)))  # header size
        f.write(header_proto)
        f.write(zip_data)


def _proto_bytes(field_num, data):
    """编码 protobuf bytes 字段 (wire type 2)。"""
    tag = (field_num << 3) | 2
    return _varint(tag) + _varint(len(data)) + data


def _varint(value):
    """编码 protobuf varint。"""
    buf = bytearray()
    while value > 0x7F:
        buf.append((value & 0x7F) | 0x80)
        value >>= 7
    buf.append(value & 0x7F)
    return bytes(buf)


def _zip_dir(path):
    """把目录打包为 ZIP bytes，文件按名称排序以保证确定性。"""
    import io
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(path):
            dirs.sort()
            for fname in sorted(files):
                fpath = os.path.join(root, fname)
                arcname = os.path.relpath(fpath, path)
                info = zipfile.ZipInfo(arcname)
                info.date_time = (2024, 1, 1, 0, 0, 0)  # 固定时间戳
                info.compress_type = zipfile.ZIP_DEFLATED
                with open(fpath, "rb") as fobj:
                    zf.writestr(info, fobj.read())
    return buf.getvalue()


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <ext_dir> <key.pem> <output.crx>", file=sys.stderr)
        sys.exit(1)
    build_crx3(sys.argv[1], sys.argv[2], sys.argv[3])
    print(f"Built CRX3: {sys.argv[3]}", file=sys.stderr)
