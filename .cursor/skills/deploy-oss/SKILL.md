# Deploy Hexo Blog to Alibaba Cloud OSS

Build the Hexo static site and sync the output to an Alibaba Cloud OSS bucket.

## Trigger

Use when the user asks to: deploy, publish, update the blog/website, sync to OSS, upload to OSS, 部署, 发布, 更新网站, 同步到OSS.

## Prerequisites

- `ossutil` is installed and configured with valid AccessKey credentials.
  If not installed, run:
  ```bash
  curl -o /tmp/ossutil-2.2.1-linux-amd64.zip https://gosspublic.alicdn.com/ossutil/v2/2.2.1/ossutil-2.2.1-linux-amd64.zip \
    && unzip -o /tmp/ossutil-2.2.1-linux-amd64.zip -d /tmp/ \
    && chmod 755 /tmp/ossutil-2.2.1-linux-amd64/ossutil \
    && sudo mv /tmp/ossutil-2.2.1-linux-amd64/ossutil /usr/local/bin/ossutil
  ```
  Then configure:
  ```bash
  ossutil config set --profile default --region cn-hangzhou \
    --access-key-id <AK_ID> --access-key-secret <AK_SECRET>
  ```
- Node.js and npm are available.
- Hexo dependencies are installed (`npm install` has been run in the project root).

## Configuration

| Variable       | Value                        |
| -------------- | ---------------------------- |
| Project Root   | Repository root (where `_config.yml` lives) |
| OSS Bucket     | `oss://tq-techweb`           |
| OSS Region     | `cn-hangzhou`                |
| Build Output   | `public/`                    |

## Steps

### Step 1 — Build

```bash
make build
```

This runs `npx hexo clean && npx hexo generate` and produces the static site in `public/`.

Verify success: the command should exit 0 and print a line like `INFO  N files generated in Xms`.

### Step 2 — Deploy to OSS

```bash
make deploy
```

Or equivalently:

```bash
ossutil sync public/ oss://tq-techweb/ --delete
```

The `--delete` flag removes files from OSS that no longer exist locally, keeping the bucket in sync.

Verify success: the command should exit 0 and print a summary of uploaded/deleted objects.

### Step 3 — Verify (optional)

Open the website URL in a browser or ask the user to confirm.

## One-liner

```bash
make deploy
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `ossutil: command not found` | Install ossutil per the Prerequisites section |
| `AccessDenied` | Re-run `ossutil config` with valid credentials |
| `hexo: command not found` | Run `npm install` in the project root |
| Build errors in markdown | Check front-matter syntax in `source/_posts/` files |
