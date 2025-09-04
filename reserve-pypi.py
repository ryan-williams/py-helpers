#!/usr/bin/env python3
"""
Reserve a PyPI package name by publishing a minimal placeholder package.

Usage:
    ./reserve-pypi.py <package_name> [--description TEXT] [--repo URL]

Environment:
    PYPI_TOKEN: PyPI API token for authentication (production)
    TEST_PYPI_TOKEN: TestPyPI API token for authentication (testing)
"""

import argparse
from functools import partial
import os
from pathlib import Path
import re
import sys
import tempfile
import shutil
import subprocess
import webbrowser
from urllib.request import Request, urlopen

err = partial(print, file=sys.stderr)


def get_repo_url_from_remote(remote_name: str) -> str | None:
    """Get repository URL from a Git remote, supporting GitHub and GitLab."""
    try:
        result = subprocess.run(
            ["git", "remote", "get-url", remote_name],
            capture_output=True,
            text=True,
            check=True
        )
        remote_url = result.stdout.strip()

        # GitHub SSH
        if remote_url.startswith("git@github.com:"):
            return remote_url.replace("git@github.com:", "https://github.com/").replace(".git", "")
        # GitHub HTTPS
        elif remote_url.startswith("https://github.com/"):
            return remote_url.replace(".git", "")
        # GitLab SSH
        elif remote_url.startswith("git@gitlab.com:"):
            return remote_url.replace("git@gitlab.com:", "https://gitlab.com/").replace(".git", "")
        # GitLab HTTPS
        elif remote_url.startswith("https://gitlab.com/"):
            return remote_url.replace(".git", "")
        # Generic GitHub/GitLab patterns
        elif "github.com" in remote_url:
            match = re.match(r".*github\.com[:/]([^/]+/[^/]+?)(?:\.git)?$", remote_url)
            if match:
                return f"https://github.com/{match.group(1)}"
        elif "gitlab.com" in remote_url:
            match = re.match(r".*gitlab\.com[:/](.+?)(?:\.git)?$", remote_url)
            if match:
                return f"https://gitlab.com/{match.group(1)}"

        return None
    except subprocess.CalledProcessError:
        return None


def parse_repo_path(path: str) -> str | None:
    """
    Parse a repository path and return full URL.
    - user/repo -> GitHub (verify it exists)
    - user/group/repo -> GitLab
    - https://... -> pass through if valid
    """
    # Already a full URL
    if path.startswith("https://"):
        return path if verify_repo_exists(path) else None

    # Count path segments
    segments = path.split('/')

    if len(segments) == 2:
        # Try GitHub first
        gh_url = f"https://github.com/{path}"
        if verify_repo_exists(gh_url):
            return gh_url
        # Fall back to GitLab
        gl_url = f"https://gitlab.com/{path}"
        if verify_repo_exists(gl_url):
            return gl_url
    elif len(segments) >= 3:
        # Assume GitLab for 3+ segments
        gl_url = f"https://gitlab.com/{path}"
        if verify_repo_exists(gl_url):
            return gl_url

    return None


def verify_repo_exists(url: str) -> bool:
    """Check if a repository exists at the given URL."""
    try:
        # Try a HEAD request first (faster)
        request = Request(url, method='HEAD')
        request.add_header('User-Agent', 'reserve-pypi/1.0')
        with urlopen(request, timeout=5) as response:
            return response.status == 200
    except:
        try:
            # Fallback to GET
            request = Request(url)
            request.add_header('User-Agent', 'reserve-pypi/1.0')
            with urlopen(request, timeout=5) as response:
                return response.status == 200
        except:
            return False


def create_minimal_package(package_name, description=None, repo_url=None):
    """Create the minimal files needed for a PyPI package."""

    # Default description if none provided
    if not description:
        description = f"Placeholder for {package_name}"

    # Create pyproject.toml (absolute minimum)
    pyproject_lines = [
        "[build-system]",
        'requires = ["setuptools>=61.0"]',
        'build-backend = "setuptools.build_meta"',
        "",
        "[project]",
        f'name = "{package_name}"',
        'version = "0.0.0"',
        f'description = "{description}"',
        'requires-python = ">=3.10"',
    ]

    if repo_url:
        pyproject_lines.extend([
            "",
            "[project.urls]",
            f'Repository = "{repo_url}"',
        ])

    pyproject_content = "\n".join(pyproject_lines)

    files = {
        "pyproject.toml": pyproject_content,
        f"{package_name}/__init__.py": "",  # Empty file
    }

    return files


def build_and_upload(work_dir, package_name, test_pypi=False, dry_run=False):
    """Build the package and upload to PyPI."""

    # Check for appropriate token
    token_var = "TEST_PYPI_TOKEN" if test_pypi else "PYPI_TOKEN"
    token = os.environ.get(token_var)
    if not token:
        err(f"Error: {token_var} environment variable not set")
        if not dry_run:
            sys.exit(1)
        # Exit with error in dry-run too
        sys.exit(1)

    index_name = "TestPyPI" if test_pypi else "PyPI"
    index_url = "https://test.pypi.org/legacy/" if test_pypi else "https://upload.pypi.org/legacy/"

    if dry_run:
        err(f"[DRY-RUN] Would build {package_name}")
        # List files that would be created
        for file in work_dir.glob("**/*"):
            if file.is_file():
                rel_path = file.relative_to(work_dir)
                err(f"  - {rel_path}")
    else:
        err(f"Building {package_name}...")
        # Build the package using the current Python interpreter
        result = subprocess.run(
            [sys.executable, "-m", "build"],
            cwd=work_dir,
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            err(f"Build failed:\n{result.stderr}")
            sys.exit(1)

    if dry_run:
        err(f"[DRY-RUN] Would upload {package_name} to {index_name}")
        if test_pypi:
            err(f"[DRY-RUN] Using repository URL: {index_url}")
        err(f"[DRY-RUN] Using token from {token_var}")
        return True

    err(f"Uploading {package_name} to {index_name}...")

    # Upload using twine with current Python interpreter
    upload_cmd = [
        sys.executable, "-m", "twine", "upload",
        "--username", "__token__",
        "--password", token,
    ]

    if test_pypi:
        upload_cmd.extend(["--repository-url", index_url])

    upload_cmd.append("dist/*")

    result = subprocess.run(
        upload_cmd,
        cwd=work_dir,
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        err(f"Upload failed:\n{result.stderr}")
        sys.exit(1)

    err(f"Successfully reserved {package_name} on {index_name}!")
    return True


def main():
    parser = argparse.ArgumentParser(description="Reserve a PyPI package name with a minimal placeholder")
    parser.add_argument("package_name", help="Name of the package to reserve")
    parser.add_argument("-d", "--description", help="Package description (default: 'Placeholder for <name>')")
    parser.add_argument("-R", "--repo", help="Repository URL or path (e.g. user/repo or https://...)")
    parser.add_argument("-r", "--remote", help="Get repository URL from Git remote")
    parser.add_argument("-t", "--test", action="store_true", help="Upload to test.pypi.org instead of pypi.org (uses TEST_PYPI_TOKEN)")
    parser.add_argument("-n", "--dry-run", action="store_true", help="Show what would be done without actually uploading")
    parser.add_argument("-O", "--no-open", action="store_true", help="Don't open the package URL in browser")
    parser.add_argument("--keep-files", action="store_true", help="Keep the temporary package files after upload")
    args = parser.parse_args()

    # Validate package name
    if not args.package_name.replace("-", "_").replace("_", "").isalnum():
        err(f"Error: Invalid package name: {args.package_name}")
        sys.exit(1)

    # Get repo URL from arguments
    repo_url = None

    if args.repo:
        # Parse and verify the repo path/URL
        repo_url = parse_repo_path(args.repo)
        if repo_url:
            err(f"Using repository URL: {repo_url}")
        else:
            err(f"Warning: Could not verify repository at '{args.repo}'")
    elif args.remote:
        # Get from Git remote
        repo_url = get_repo_url_from_remote(args.remote)
        if repo_url:
            err(f"Using repository URL from Git remote '{args.remote}': {repo_url}")
            # Verify it exists
            if not verify_repo_exists(repo_url):
                err(f"Warning: Could not verify repository exists at {repo_url}")
                repo_url = None
        else:
            err(f"Warning: Could not parse repository URL from remote '{args.remote}'")

    # Create temporary directory for package
    if args.keep_files or args.dry_run:
        work_dir = Path(f"reserve-{args.package_name}")
        work_dir.mkdir(exist_ok=True)
        if args.dry_run:
            err(f"[DRY-RUN] Creating package in: {work_dir}")
        else:
            err(f"Creating package in: {work_dir}")
    else:
        temp_dir = tempfile.mkdtemp(prefix=f"reserve-{args.package_name}-")
        work_dir = Path(temp_dir)
        err(f"Creating package in temporary directory: {work_dir}")

    try:
        # Create package files
        files = create_minimal_package(
            args.package_name,
            args.description,
            repo_url,
        )

        # Write files
        for filepath, content in files.items():
            full_path = work_dir / filepath
            full_path.parent.mkdir(parents=True, exist_ok=True)
            full_path.write_text(content)
            err(f"  Created: {filepath}")

        # Build and upload
        build_and_upload(work_dir, args.package_name, args.test, args.dry_run)

        # Determine the package URL
        if args.test:
            package_url = f"https://test.pypi.org/project/{args.package_name}/"
        else:
            package_url = f"https://pypi.org/project/{args.package_name}/"

        if args.dry_run:
            err(f"\n[DRY-RUN] Package {args.package_name} would be reserved")
            print(package_url)
        else:
            err(f"\nPackage {args.package_name} successfully reserved!")
            print(package_url)

            # Open in browser unless disabled
            if not args.no_open:
                err(f"Opening {package_url} in browser...")
                webbrowser.open(package_url)

    finally:
        # Clean up unless --keep-files or --dry-run was specified
        if not args.keep_files and not args.dry_run and work_dir.exists():
            shutil.rmtree(work_dir)
            err(f"Cleaned up temporary files")
        elif args.dry_run and not args.keep_files and work_dir.exists():
            shutil.rmtree(work_dir)
            err(f"[DRY-RUN] Cleaned up temporary files")


if __name__ == "__main__":
    main()
