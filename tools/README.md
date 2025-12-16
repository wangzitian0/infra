# tools

本目录放置**轻量脚本**（CI/本地校验用），不属于 Terraform layer（`0.tools/1.bootstrap/...`）。

## `check_images.py`

用途：预先校验 Docker Hub 上的镜像 tag 是否存在，避免部署时出现 `ImagePullBackOff` 才发现问题。

```bash
python3 tools/check_images.py nginx:1.27 postgres:16
```

> 需要联网访问 `auth.docker.io` 与 `registry-1.docker.io`。
