import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

def set_cell_background(cell, color_hex):
    tcPr = cell._element.get_or_add_tcPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'), 'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'), color_hex)
    tcPr.append(shd)

def create_document():
    doc = docx.Document()
    
    # Page setup
    for section in doc.sections:
        section.top_margin = Inches(1.0)
        section.bottom_margin = Inches(1.0)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)

    # Styles Setup
    style_normal = doc.styles['Normal']
    style_normal.font.name = 'Arial'
    style_normal.font.size = Pt(10.5)
    style_normal.font.color.rgb = RGBColor(0x2D, 0x37, 0x48) # Charcoal

    # Document Header / Cover Style
    title = doc.add_paragraph()
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    title_run = title.add_run("TRUST TRACKER\nDESIGN SYSTEM SPECIFICATION")
    title_run.font.name = 'Helvetica'
    title_run.font.size = Pt(26)
    title_run.font.bold = True
    title_run.font.color.rgb = RGBColor(0x3B, 0x82, 0xF6) # Primary Blue

    subtitle = doc.add_paragraph()
    subtitle.alignment = WD_ALIGN_PARAGRAPH.CENTER
    sub_run = subtitle.add_run("Centralized Enterprise-Grade Fintech UI Architecture & Foundation")
    sub_run.font.name = 'Arial'
    sub_run.font.size = Pt(13)
    sub_run.font.italic = True
    sub_run.font.color.rgb = RGBColor(0x71, 0x80, 0x96) # Slate

    doc.add_paragraph("\n" * 2)

    # Executive Summary
    h_exec = doc.add_heading(level=1)
    run_exec = h_exec.add_run("1. Executive Summary & Design Principles")
    run_exec.font.size = Pt(18)
    run_exec.font.color.rgb = RGBColor(0x1A, 0x36, 0x5D) # Navy

    p_exec = doc.add_paragraph(
        "The Trust Tracker Design System has been centralized to provide an offline-first, "
        "premium, and highly cohesive visual language for personal finance management. "
        "By modularizing design parameters into distinct Dart components (Colors, Gradients, Typography, "
        "Shadows, Spacing, and Animations), we ensure absolute visual consistency across all pages, modules, "
        "and future extensions (including the upcoming web landing pages and marketing assets)."
    )
    p_exec.paragraph_format.line_spacing = 1.25
    p_exec.paragraph_format.space_after = Pt(12)

    # Key Objectives
    p_obj = doc.add_paragraph()
    p_obj.add_run("Core Design Pillars:\n").bold = True
    p_obj.add_run("• Premium Fintech Aesthetics: ").bold = True
    p_obj.add_run("Utilizes tailored HSL colors, dark obsidian backgrounds, smooth curves, and clean typography to evoke security and prestige.\n")
    p_obj.add_run("• Complete Separation of Concerns: ").bold = True
    p_obj.add_run("Theme constants are completely isolated from functional views and business logic, encouraging reusable code blocks.\n")
    p_obj.add_run("• Fluid Transitions & Micro-interactions: ").bold = True
    p_obj.add_run("Maintains high-frame-rate feedback with a unified system of durations and curves.\n")
    p_obj.add_run("• Bulletproof Dark Mode Consistency: ").bold = True
    p_obj.add_run("Replaces standard glaring dark colors with obsidian surface layers to establish a solid depth hierarchy.\n")

    # Colors Section
    h_colors = doc.add_heading(level=1)
    run_colors = h_colors.add_run("2. Theme & Color Specification")
    run_colors.font.size = Pt(18)
    run_colors.font.color.rgb = RGBColor(0x1A, 0x36, 0x5D)

    p_colors_intro = doc.add_paragraph(
        "Colors are categorized into Brand Neutrals, Brand Accents, and Functional Indicators. "
        "Dark mode uses high-contrast obsidian tones for optimal legibility and high visual prestige."
    )

    # Color Palette Table
    table = doc.add_table(rows=1, cols=4)
    table.style = 'Light Shading Accent 1'
    hdr_cells = table.rows[0].cells
    hdr_cells[0].text = 'Color Name'
    hdr_cells[1].text = 'Hex Code / RGB'
    hdr_cells[2].text = 'Light Mode Role'
    hdr_cells[3].text = 'Dark Mode Role'

    colors_data = [
        ("Primary (Seed)", "#3B82F6", "Active highlights, key CTAs, branding accents", "Retained brand representation across elements"),
        ("Light Background", "#F8F9FA", "Soft gray full-screen background canvas", "N/A"),
        ("Light Surface", "#FFFFFF", "Clean white card bases and dialog windows", "N/A"),
        ("Dark Background", "#0F0F11", "N/A", "Deep premium obsidian full-screen canvas"),
        ("Dark Surface", "#18181C", "N/A", "Elevated surface tiles, containers, base sheets"),
        ("Dark Surface Variant", "#222228", "N/A", "Highest elevation layer, dropdown menus, snackbars"),
        ("Success Green", "#10B981", "Income indicator, positive balance trend, safe", "Emerald Green indicator, optimized contrast"),
        ("Error Red", "#EF4444", "Expenses indicator, over-budget notifications, delete", "Vivid crimson alerting, highly legible against dark"),
        ("Warning Amber", "#F59E0B", "Alerts, near-limit progress states, caution", "High contrast golden-amber for secondary alerts"),
    ]

    for name, hex_code, light_role, dark_role in colors_data:
        row_cells = table.add_row().cells
        row_cells[0].text = name
        row_cells[1].text = hex_code
        row_cells[2].text = light_role
        row_cells[3].text = dark_role

    doc.add_paragraph("\n")

    # Typography Section
    h_typo = doc.add_heading(level=1)
    run_typo = h_typo.add_run("3. Unified Typography & Scaling System")
    run_typo.font.size = Pt(18)
    run_typo.font.color.rgb = RGBColor(0x1A, 0x36, 0x5D)

    p_typo = doc.add_paragraph(
        "Typography is divided between Manrope (used for prominent titles and figures to give a professional "
        "tech feel) and Inter (used for highly readable descriptions, values, body contents, and labels)."
    )

    # Typography Table
    table_t = doc.add_table(rows=1, cols=4)
    table_t.style = 'Light Shading Accent 1'
    hdr_t = table_t.rows[0].cells
    hdr_t[0].text = 'Typography Name'
    hdr_t[1].text = 'Font Family'
    hdr_t[2].text = 'Size / Weight / Spacing'
    hdr_t[3].text = 'Intended Usage'

    typo_data = [
        ("Display Large", "Manrope", "40pt / ExtraBold / -1.5 tracking", "Hero figures, major dollar balances"),
        ("Display Medium", "Manrope", "32pt / ExtraBold / -1.0 tracking", "Primary net balances, page totals"),
        ("Display Small", "Manrope", "24pt / ExtraBold / 0.0 tracking", "Monthly overview amounts, secondary totals"),
        ("Headline Medium", "Manrope", "20pt / Bold / 0.0 tracking", "Page titles, major greeting headers"),
        ("Headline Small", "Manrope", "18pt / Bold / 0.0 tracking", "Section titles, sheet headings"),
        ("Title Medium", "Inter", "16pt / SemiBold / 0.0 tracking", "List items descriptions, field input labels"),
        ("Body Medium", "Inter", "14pt / Medium / 0.0 tracking", "Sub-texts, secondary category details"),
        ("Label Small", "Inter", "11pt / SemiBold / +0.5 tracking", "Quick tabs, transaction badges"),
    ]

    for name, family, specs, usage in typo_data:
        row_cells = table_t.add_row().cells
        row_cells[0].text = name
        row_cells[1].text = family
        row_cells[2].text = specs
        row_cells[3].text = usage

    doc.add_paragraph("\n")

    # Spacing and Layout
    h_layout = doc.add_heading(level=1)
    run_layout = h_layout.add_run("4. Centralized Dimensions & Corner Radius")
    run_layout.font.size = Pt(18)
    run_layout.font.color.rgb = RGBColor(0x1A, 0x36, 0x5D)

    p_layout = doc.add_paragraph(
        "All visual spaces are mapped to a geometric factor of 4. This ensures flawless alignment across both "
        "mobile screens and wider landing page canvases."
    )

    p_dims = doc.add_paragraph()
    p_dims.add_run("Unified Dimensions Matrix:\n").bold = True
    p_dims.add_run("• Spacers & Padding: ").bold = True
    p_dims.add_run("xs (4.0px) | sm (8.0px) | md (12.0px) | lg (16.0px) | xl (20.0px) | xxl (24.0px) | xxxl (32.0px)\n")
    p_dims.add_run("• Corner Radiuses: ").bold = True
    p_dims.add_run("rXs (4.0px) | rSm (8.0px) | rMd (12.0px) | rLg (14.0px) | rXl (16.0px) | rXxl (18.0px) | r3Xl (24.0px)\n")
    p_dims.add_run("• Interactive Heights: ").bold = True
    p_dims.add_run("App Bar (56.0px) | Bottom Bar (64.0px) | Primary Buttons (54.0px)\n")

    # Gradients and Shadows
    h_grad = doc.add_heading(level=1)
    run_grad = h_grad.add_run("5. Gradients & Shadow Architecture")
    run_grad.font.size = Pt(18)
    run_grad.font.color.rgb = RGBColor(0x1A, 0x36, 0x5D)

    p_grad = doc.add_paragraph(
        "Gradients are used strictly for high-visibility summary containers, primary action cards, and progress "
        "tracks. Shadows utilize subtle translucent values to establish distinct layer depths without visual clutter."
    )

    p_grad_specs = doc.add_paragraph()
    p_grad_specs.add_run("Visual Elements Specs:\n").bold = True
    p_grad_specs.add_run("• Primary Brand Gradient: ").bold = True
    p_grad_specs.add_run("seedColor to seedColor.withBlue(220) from Top-Left to Bottom-Right.\n")
    p_grad_specs.add_run("• Functional Success Gradient: ").bold = True
    p_grad_specs.add_run("#10B981 to #059669 (Emerald linear blend).\n")
    p_grad_specs.add_run("• Soft Card Shadows: ").bold = True
    p_grad_specs.add_run("Black with 3% Opacity, Blur: 10px, Offset: (0, 4px) to represent natural elevation.\n")
    p_grad_specs.add_run("• High Intensity Brand Glow: ").bold = True
    p_grad_specs.add_run("Primary Color with 15% Opacity, Blur: 20px, Offset: (0, 4px), Spread: 2px.\n")

    # Animations
    h_anim = doc.add_heading(level=1)
    run_anim = h_anim.add_run("6. Transition Durations & Animation Curves")
    run_anim.font.size = Pt(18)
    run_anim.font.color.rgb = RGBColor(0x1A, 0x36, 0x5D)

    p_anim = doc.add_paragraph(
        "User interactions are accompanied by micro-animations defined under AppAnimations. "
        "The system uses Fast (150ms) for instant feedback like clicks, Medium (300ms) for modal cards, "
        "and Slow (500ms) for major page navigation. The default animation curve is Curves.fastOutSlowIn "
        "for a premium startup-quality feel."
    )

    # Core files list
    h_files = doc.add_heading(level=1)
    run_files = h_files.add_run("7. Centralized Architecture Files")
    run_files.font.size = Pt(18)
    run_files.font.color.rgb = RGBColor(0x1A, 0x36, 0x5D)

    p_files = doc.add_paragraph(
        "The following files have been integrated under lib/core/theme/ to organize the design system "
        "and enable seamless updates across all mobile and web platform interfaces:\n"
    )

    files_list = [
        ("app_colors.dart", "Defines the brand palettes, neutrals, accents, and light/dark modes surface layers."),
        ("app_gradients.dart", "Pre-configured linear gradients for cards, charts, and functional elements."),
        ("app_text_styles.dart", "Centralized Google Fonts mappings for consistent cross-platform rendering."),
        ("app_shadows.dart", "Predefined light & intense elevation depths using refined opacity profiles."),
        ("app_dimensions.dart", "Establishes layout parameters, borders, icons, and page offsets."),
        ("app_animations.dart", "Maintains timing constants and animation curves for natural tactile responses."),
        ("app_theme.dart", "Aggregates all specifications into unified dark/light MaterialApp ThemeData classes, keeping backward-compatible exports.")
    ]

    for f_name, f_desc in files_list:
        p_f = doc.add_paragraph()
        p_f.add_run(f"• {f_name}: ").bold = True
        p_f.add_run(f_desc)

    doc.add_paragraph("\n")
    
    # Sign off
    p_sign = doc.add_paragraph()
    p_sign.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    p_sign.add_run("Prepared for Karan - Trust Tracker Lead\n").bold = True
    p_sign.add_run("Generated by Antigravity Design Agent\n")
    p_sign.add_run("Status: Production-Ready Design centralisation complete.")

    doc.save("Trust_Tracker_Design_System.docx")
    print("Trust_Tracker_Design_System.docx created successfully!")

if __name__ == "__main__":
    create_document()
