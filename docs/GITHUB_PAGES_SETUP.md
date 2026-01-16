# GitHub Pages Setup Instructions

This guide will help you publish this script as a GitHub Pages site.

## Quick Setup

### 1. Push to GitHub

```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/YOUR-USERNAME/podman-desktop-lima-setup.git
git branch -M main
git push -u origin main
```

### 2. Enable GitHub Pages

1. Go to your repository on GitHub
2. Click **Settings** → **Pages** (left sidebar)
3. Under **Source**, select:
   - **Source**: GitHub Actions
4. Click **Save**

### 3. Wait for Deployment

The GitHub Actions workflow will automatically:
- Build the site from README.md
- Deploy to GitHub Pages
- Make the script available at a URL

Check deployment progress in the **Actions** tab.

### 4. Get Your Site URL

Your site will be available at:
```
https://YOUR-USERNAME.github.io/podman-desktop-lima-setup/
```

The script will be accessible at:
```
https://YOUR-USERNAME.github.io/podman-desktop-lima-setup/setup-podman-lima.sh
```

### 5. Update Installation URLs

Update the installation URLs in README.md:

Replace `YOUR-USERNAME` with your actual GitHub username:

```bash
# In README.md, change:
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/podman-desktop-lima-setup/main/setup-podman-lima.sh)

# To your GitHub Pages URL (optional, both work):
bash <(curl -fsSL https://YOUR-USERNAME.github.io/podman-desktop-lima-setup/setup-podman-lima.sh)
```

Both URLs work, but GitHub Pages URL:
- ✅ Serves from CDN (faster)
- ✅ Better for public distribution
- ✅ Can use custom domain

Raw GitHub URL:
- ✅ Always reflects latest commit
- ✅ No build process needed

## Custom Domain (Optional)

### 1. Add Custom Domain

1. Go to repository **Settings** → **Pages**
2. Under **Custom domain**, enter your domain (e.g., `podman-lima.example.com`)
3. Click **Save**

### 2. Configure DNS

Add a CNAME record with your DNS provider:

```
Type:  CNAME
Name:  podman-lima (or @ for root domain)
Value: YOUR-USERNAME.github.io
```

### 3. Update CNAME File

Edit `docs/CNAME` and add your domain:

```
podman-lima.example.com
```

## Verification

Test your deployment:

```bash
# Test the page loads
curl -I https://YOUR-USERNAME.github.io/podman-desktop-lima-setup/

# Test the script is accessible
curl -fsSL https://YOUR-USERNAME.github.io/podman-desktop-lima-setup/setup-podman-lima.sh | head -n 5

# Test installation (dry run - won't actually install)
curl -fsSL https://YOUR-USERNAME.github.io/podman-desktop-lima-setup/setup-podman-lima.sh | bash -s -- --help
```

## Troubleshooting

### Pages Not Building

1. Check **Actions** tab for build errors
2. Ensure `_config.yml` is present in docs directory
3. Verify GitHub Pages is enabled in Settings

### 404 Error

1. Wait 5-10 minutes after first push
2. Check that workflow completed successfully
3. Clear browser cache and retry

### Script Not Found

1. Verify `setup-podman-lima.sh` was copied to docs directory
2. Check Actions workflow completed
3. Try the raw GitHub URL instead

## Updating Content

Every push to `main` branch automatically:
1. Rebuilds the GitHub Pages site
2. Updates the installation script
3. Refreshes the documentation

No manual deployment needed!

## Alternative: Use Raw GitHub URL Only

If you prefer not to use GitHub Pages:

1. **Don't enable GitHub Pages** in settings
2. Use only the raw.githubusercontent.com URL:
   ```bash
   bash <(curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/podman-desktop-lima-setup/main/setup-podman-lima.sh)
   ```

This URL:
- Always reflects the latest commit to main branch
- No build process or configuration needed
- Works immediately after pushing to GitHub
