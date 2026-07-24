# Zhuyi Lago deployment overlay

Target:

- ACK cluster: `lincanvas`
- Namespace: `lago-zhuyi`
- Domain: `lago.artentiongroup.com`
- Canvas public URL: `https://jifuwu.artentiongroup.com`
- Database: `lago_zhuyi` with a dedicated `lago_zhuyi` account
- Object storage: Qiniu Kodo through its S3-compatible endpoint
- Kodo account and bucket: shared with Zhuyi Canvas, bucket `lincanvas`
- Kodo S3 region: `cn-east-1`

The overlay contains no credentials. Create `lago-runtime`,
`lago-connections`, and `lago-artentiongroup-com-tls` separately.

Required render variables:

```bash
export IMAGE_TAG=<immutable-git-sha>
```

The Kodo endpoint, region, bucket, and path-style setting are fixed in
`configmaps.yaml`. The Kodo access key and secret key remain in the
`lago-runtime` Secret and match the domestic Kodo account used by
`zhuyi-canvas`.

Render and review without applying:

```bash
deploy/overlays/zhuyi/render.sh bootstrap
deploy/overlays/zhuyi/render.sh apps
deploy/overlays/zhuyi/render.sh migrate
deploy/overlays/zhuyi/render.sh runtime
deploy/overlays/zhuyi/render.sh ingress
deploy/overlays/zhuyi/render.sh workloads
```

Release order:

1. Apply `render.sh bootstrap` for the Namespace, ConfigMaps, Services, quota,
   and migration script.
2. Confirm the managed `aliyun-acr-credential-helper` watches `lago-zhuyi`
   and the default ServiceAccount references
   `acr-credential-secret-aggregation`.
3. Allow the ACK pod network in the dedicated Redis instance. The current
   deployment mirrors the existing Lago `default` whitelist:
   `10.0.0.0/8,127.0.0.1`.
4. Create a unique migration Job and wait for `Complete`.
5. Only after migration succeeds, apply `render.sh runtime` for Deployments
   and PDBs. Wait for every Deployment rollout and run internal health checks.
6. Obtain a certificate covering `lago.artentiongroup.com` from the customer
   and create `lago-artentiongroup-com-tls` in `lago-zhuyi`.
7. Apply `render.sh ingress`, then ask the customer to CNAME
   `lago.artentiongroup.com` to the shared ALB hostname and run external HTTPS
   checks.

`render.sh workloads` remains available when the TLS Secret already exists and
the runtime and Ingress can be applied together.

The checked-in overlay keeps `LAGO_SKIP_PG_PARTMAN=true`, matching the
currently verified deployment path. Re-review the migration script for every
Lago API version before changing this setting.
