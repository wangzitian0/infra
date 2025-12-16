#!/usr/bin/env python3
import sys
import json
import urllib.request
import urllib.error

def check_image(image_tag):
    """
    Checks if a Docker image tag exists in a public registry.
    Supports standard Docker Hub images (library/ or namespace/).
    Uses standard library urllib to avoid external dependencies.
    """
    print(f"Checking image: {image_tag} ... ", end="", flush=True)

    if ":" in image_tag:
        repo, tag = image_tag.split(":", 1)
    else:
        repo, tag = image_tag, "latest"

    # Handle official library images (e.g. "postgres" -> "library/postgres")
    if "/" not in repo:
        repo = f"library/{repo}"
    
    # Docker Hub Registry V2 API
    # 1. Get Token
    auth_url = f"https://auth.docker.io/token?service=registry.docker.io&scope=repository:{repo}:pull"
    try:
        with urllib.request.urlopen(auth_url, timeout=10) as response:
            token_data = json.loads(response.read().decode())
            token = token_data.get("token")
    except Exception as e:
        print(f"FAIL (Auth Error: {e})")
        return False

    # 2. Check Manifest
    manifest_url = f"https://registry-1.docker.io/v2/{repo}/manifests/{tag}"
    headers = {
        "Authorization": f"Bearer {token}",
        # Accept manifest v2 (schema 2) and manifest list v2
        "Accept": "application/vnd.docker.distribution.manifest.v2+json,application/vnd.docker.distribution.manifest.list.v2+json"
    }

    try:
        req = urllib.request.Request(manifest_url, headers=headers, method="HEAD")
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status == 200:
                print("OK")
                return True
            else:
                # Should normally raise HTTPError for non-2xx
                print(f"FAIL (Status: {response.status})")
                return False
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print("NOT FOUND")
            return False
        else:
            print(f"FAIL (HTTP {e.code}: {e.reason})")
            return False
    except Exception as e:
        print(f"FAIL (Network Error: {e})")
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: check_images.py <image1> <image2> ...")
        sys.exit(1)

    images = sys.argv[1:]
    failed_images = []

    print("--- Pre-flight Image Availability Check ---")
    for img in images:
        if not check_image(img):
            failed_images.append(img)
    
    if failed_images:
        print("\n[ERROR] The following images were not found or failed validation:")
        for img in failed_images:
            print(f"  - {img}")
        print("Deployment aborted to prevent ImagePullBackOff.")
        sys.exit(1)
    
    print("\n[SUCCESS] All images verified available.")
    sys.exit(0)

if __name__ == "__main__":
    main()
