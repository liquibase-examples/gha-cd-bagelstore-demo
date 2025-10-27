#!/usr/bin/env python3
"""
Render Mermaid diagrams from markdown using Playwright.
Uses mermaid.live to render diagrams and captures screenshots.
"""

import re
import sys
import tempfile
from pathlib import Path
from playwright.sync_api import sync_playwright


def extract_mermaid_diagrams(markdown_file):
    """Extract all Mermaid diagrams from a markdown file."""
    content = Path(markdown_file).read_text()

    # Find all mermaid code blocks
    pattern = r'```mermaid\n(.*?)```'
    diagrams = re.findall(pattern, content, re.DOTALL)

    return diagrams


def render_diagram(page, diagram_code, output_path):
    """Render a single Mermaid diagram and save screenshot."""
    print(f"Rendering diagram to {output_path}...")

    # Navigate to Mermaid Live Editor
    page.goto("https://mermaid.live/edit", wait_until="networkidle")

    # Wait for editor to load
    page.wait_for_selector("textarea.code-editor", timeout=10000)

    # Clear existing content and paste new diagram
    textarea = page.locator("textarea.code-editor").first
    textarea.click()
    page.keyboard.press("Meta+A")  # Select all (Cmd+A on Mac)
    page.keyboard.press("Backspace")
    textarea.fill(diagram_code)

    # Wait for diagram to render
    page.wait_for_timeout(2000)

    # Find and screenshot the diagram preview
    preview = page.locator("#preview").first
    preview.screenshot(path=output_path)

    print(f"✓ Saved: {output_path}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python render-mermaid.py <markdown-file>")
        print("Example: python render-mermaid.py docs/ARCHITECTURE_DIAGRAMS.md")
        sys.exit(1)

    markdown_file = sys.argv[1]

    if not Path(markdown_file).exists():
        print(f"Error: File not found: {markdown_file}")
        sys.exit(1)

    print(f"Extracting Mermaid diagrams from {markdown_file}...")
    diagrams = extract_mermaid_diagrams(markdown_file)

    if not diagrams:
        print("No Mermaid diagrams found!")
        sys.exit(1)

    print(f"Found {len(diagrams)} diagram(s)\n")

    # Create output directory
    output_dir = Path("docs/architecture-renders")
    output_dir.mkdir(exist_ok=True)

    # Render each diagram
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1920, "height": 1080})

        for i, diagram in enumerate(diagrams, 1):
            output_path = output_dir / f"diagram-{i}.png"
            try:
                render_diagram(page, diagram, str(output_path))
            except Exception as e:
                print(f"✗ Error rendering diagram {i}: {e}")

        browser.close()

    print(f"\n✓ All diagrams rendered to {output_dir}/")
    print(f"\nView them with: open {output_dir}")


if __name__ == "__main__":
    main()
