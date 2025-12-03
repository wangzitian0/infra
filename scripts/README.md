# Scripts Overview

入口脚本（部署相关）：
- `deploy/layered_deploy.sh` — 分层执行 Terraform plan/apply → 导出自托管 Infisical 密钥 → `deploy.sh`（compose 部署，无 UI）  
- `deploy/deploy.sh` — 仅应用层 compose 部署（依赖 `.env.<env>` 或 export-secrets）  
- `deploy/export-secrets.sh` — 从自托管 Infisical 导出环境变量到 `.env.<env>`

说明：
- Dokploy 控制面：`cloud.truealpha.club`（单台 VPS 103.214.23.41）；目前 deploy.sh 直接用 compose，后续可接 Dokploy API。  
- Terraform 层：从 `layered_deploy.sh` 调用（env: staging/test/prod）。  
- 目录最小化保留 deploy/；其他脚本按需补充。 "*** End Patch" where? Wait need valid patch*** Sorry stop. Need proper apply_patch syntax.
