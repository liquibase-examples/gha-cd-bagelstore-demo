# Bagel Store Demo Presentation

Executive-focused HTML presentation showcasing coordinated database and application deployments using Harness CD, GitHub Actions, Liquibase, and AWS.

## Quick Start

### View Presentation

**Option 1: Direct Browser**
```bash
cd presentation
open index.html
# Or on Linux: xdg-open index.html
# Or on Windows: start index.html
```

**Option 2: Local Web Server (Recommended)**
```bash
cd presentation
python3 -m http.server 8000
# Then open: http://localhost:8000
```

### Navigation

- **Next slide**: Space, →, ↓, or N
- **Previous slide**: ←, ↑, or P
- **Overview mode**: ESC or O
- **Speaker notes**: S
- **Fullscreen**: F
- **Jump to slide**: Type slide number + Enter

## Presentation Structure

### 19 Slides - ~25-30 Minutes

1. **Title** - Introduction
2. **The Challenge** - Traditional vs Modern approach
3. **Solution Architecture** - High-level flow
4. **Technology Stack** - All technologies with badges
5. **Environment Promotion** - Dev → Test → Staging → Prod
6. **Infrastructure as Code** - Terraform automation
7. **Developer Workflow** - Creating database changes
8. **PR Validation** - Automated policy checks
9. **CI/CD Pipeline** - Parallel builds
10. **Dev Deployment** - Automatic coordinated deployment
11. **Promotion Gates** - Manual approval controls
12. **Policy Checks** - 12 BLOCKER-level governance rules
13. **Liquibase Flows** - Structured automation
14. **AWS Integration** - RDS, App Runner, S3, Secrets Manager
15. **Harness Terraform** - Zero-config deployments
16. **Multi-Instance** - Demo isolation via demo_id
17. **Business Value** - 6 key benefits
18. **Complete Architecture** - System diagram
19. **Questions** - Next steps

## Presenter Notes

Each slide includes detailed speaker notes accessible by pressing **S** during presentation.

**Key sections with notes:**
- Slide 3: Architecture flow explanation
- Slide 8: Policy check enforcement details
- Slide 10: Coordinated deployment sequence
- Slide 15: Terraform provider benefits

## Target Audience

**Primary:** C-level executives, VPs, senior leadership
**Secondary:** Technical decision makers, architects

**Focus:**
- Business value over technical details
- Developer experience and productivity
- Safety, compliance, audit trail
- Cost efficiency and scalability

## Customization

### Update Content

Edit `index.html` directly. Each slide is a `<section>` element:

```html
<section>
    <h2>Slide Title</h2>
    <p>Slide content...</p>
    <aside class="notes">
        Speaker notes go here
    </aside>
</section>
```

### Update Styling

Edit `assets/css/custom.css`:

- Color scheme: CSS variables in `:root`
- Layout: Grid/flexbox classes
- Component styles: Each section documented

### Add Logos

1. Download official logos (see `assets/images/logos/placeholder.md`)
2. Place in `assets/images/logos/`
3. Reference in HTML:
   ```html
   <img src="assets/images/logos/github.png" alt="GitHub" style="height: 80px;">
   ```

### Add Diagrams

1. Create diagrams using your preferred tool
2. Export as PNG or SVG
3. Place in `assets/images/diagrams/`
4. Add to slides:
   ```html
   <img src="assets/images/diagrams/architecture.png" alt="Architecture">
   ```

## Export to PDF

### Method 1: Print to PDF (Chrome)

1. Open presentation in Chrome
2. Add `?print-pdf` to URL: `http://localhost:8000/?print-pdf`
3. Open Print dialog (Ctrl/Cmd + P)
4. Select "Save as PDF"
5. **Important settings:**
   - Layout: Landscape
   - Margins: None
   - Background graphics: Enabled

### Method 2: Decktape (Better Quality)

```bash
# Install decktape
npm install -g decktape

# Generate PDF
decktape reveal http://localhost:8000 presentation.pdf
```

## Presenter Tips

### Before Presentation

1. ✅ Test slides in fullscreen mode
2. ✅ Review speaker notes (press S)
3. ✅ Test all navigation (arrows, overview, jump)
4. ✅ Have live demo environment ready
5. ✅ Bookmark key URLs (GitHub repo, Harness UI, AWS console)

### During Presentation

**Recommended Flow:**
1. Start with Title (slide 1)
2. Explain Challenge (slide 2)
3. Show Architecture (slides 3-6)
4. Walk through Developer Experience (slides 7-11)
5. Highlight Key Features (slides 12-16)
6. Summarize Business Value (slide 17)
7. Show Complete System (slide 18)
8. Open for Questions (slide 19)

**Interactive Elements:**
- Switch to live demo after slide 11
- Show GitHub PR with policy check results
- Navigate Harness pipeline execution
- Display app in each environment

### Time Management

- **Executive version**: 15-20 min (slides 1, 2, 3, 5, 10, 11, 17, 18, 19)
- **Technical version**: 25-30 min (all slides)
- **Deep dive version**: 45-60 min (all slides + live demo + Q&A)

## Technical Details

### Built With

- **reveal.js 5.0.4** - HTML presentation framework
- **Monokai theme** - Code syntax highlighting
- **Custom CSS** - Harness/AWS/GitHub color scheme

### Browser Support

- ✅ Chrome/Edge (Recommended)
- ✅ Firefox
- ✅ Safari
- ⚠️ IE11 not supported

### Features Used

- Slide transitions (fade/slide)
- Speaker notes
- Code syntax highlighting
- Slide numbering
- PDF export
- Overview mode
- Jump to slide

## Troubleshooting

**Slides don't display correctly**
- Try using a local web server instead of opening file directly
- Check browser console for JavaScript errors

**Code syntax highlighting broken**
- Ensure internet connection (loads highlight.js from CDN)
- Check that code blocks have proper language class

**Speaker notes don't open**
- Press S (uppercase or lowercase)
- Check that popup blocker isn't blocking notes window

**PDF export issues**
- Make sure to add `?print-pdf` to URL before printing
- Use landscape orientation
- Enable background graphics in print settings

## Additional Resources

### reveal.js Documentation
- Official docs: https://revealjs.com/
- Keyboard shortcuts: https://revealjs.com/keyboard/
- Markdown slides: https://revealjs.com/markdown/

### Related Project Documentation
- [Main README](../README.md) - Project overview
- [Requirements Doc](../requirements-design-plan.md) - Complete system design
- [Harness Pipelines](../harness/pipelines/README.md) - Pipeline documentation
- [GitHub Workflows](../docs/WORKFLOWS.md) - CI/CD workflows

## License

Presentation content is part of the harness-gha-bagelstore demo project.

Technology logos and trademarks are property of their respective owners. Use in accordance with each company's brand guidelines.

---

**Built with modern DevOps practices for executive communication** ✨
