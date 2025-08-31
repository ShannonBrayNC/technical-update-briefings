import os
from pptx.util import Pt
from pptx.enum.text import PP_ALIGN
from pptx.dml.color import RGBColor

# Helper functions for conversions
def inches_to_emu(x):
    return int(x * 914400)  # EMU per inch



def add_full_slide_picture(slide, prs, image_path):
    """Add a background image stretched over the full slide."""
    if not image_path or not os.path.exists(image_path):
        return
    slide.shapes.add_picture(
        image_path,
        0,
        0,
        width=inches_to_emu(10),
        height=inches_to_emu(7.5),
    )

def add_picture_safe(slide, image_path, left_in, top_in, width_in=None, height_in=None):
    """Safely add a picture if file exists."""
    if not image_path or not os.path.exists(image_path):
        return
    try:
        from pptx.util import Inches
        if width_in is None and height_in is None:
            slide.shapes.add_picture(image_path, inches_to_emu(left_in), inches_to_emu(top_in))
        elif width_in is not None and height_in is None:
            slide.shapes.add_picture(image_path, inches_to_emu(left_in), inches_to_emu(top_in), width=inches_to_emu(width_in))
        elif width_in is None and height_in is not None:
            slide.shapes.add_picture(image_path, inches_to_emu(left_in), inches_to_emu(top_in), height=inches_to_emu(height_in))
        else:
            slide.shapes.add_picture(image_path, inches_to_emu(left_in), inches_to_emu(top_in), width=inches_to_emu(width_in), height=inches_to_emu(height_in))
    except Exception as e:
        print(f"Error adding picture {image_path}: {e}")

def add_title_box(slide, text, *, left_in, top_in, width_in, height_in, font_size_pt=60, bold=True, color="#FFFFFF", align=PP_ALIGN.LEFT):
    """Add a styled title textbox."""
    from pptx.util import Inches
    textbox = slide.shapes.add_textbox(Inches(left_in), Inches(top_in), Inches(width_in), Inches(height_in))
    tf = textbox.text_frame
    tf.clear()
    tf.word_wrap = True
    tf.auto_size = True
    p = tf.paragraphs[0]
    p.alignment = align
    r = p.add_run()
    r.text = text or ""
    r.font.size = Pt(font_size_pt)
    r.font.bold = bold
    r.font.color.rgb = RGBColor.from_string(color)

def add_text_box(slide, text, *, left_in, top_in, width_in, height_in, font_size_pt=18, bold=False, color="#FFFFFF", align=PP_ALIGN.LEFT):
    """Add styled text box."""
    from pptx.util import Inches
    textbox = slide.shapes.add_textbox(Inches(left_in), Inches(top_in), Inches(width_in), Inches(height_in))
    tf = textbox.text_frame
    tf.clear()
    tf.word_wrap = True
    tf.auto_size = True
    p = tf.paragraphs[0]
    p.alignment = align
    r = p.add_run()
    r.text = text or ""
    r.font.size = Pt(font_size_pt)
    r.font.bold = bold
    r.font.color.rgb = RGBColor.from_string(color)

# Now define your slide templates functions:

def add_cover_slide(prs, assets, cover_title, cover_dates, logo1_path, logo2_path):
    slide = prs.slides.add_slide(prs.slide_layouts[6])  # blank layout
    add_full_slide_picture(slide, prs, assets.get("cover"))
    # Title text
    add_title_box(
        slide,
        cover_title or "Title",
        left_in=0.5,
        top_in=2,
        width_in=9,
        height_in=2,
        font_size_pt=52,
        color="#FFFFFF",
        align=PP_ALIGN.CENTER
    )
    # Dates text
    if cover_dates:
        add_text_box(
            slide,
            cover_dates,
            left_in=0.5,
            top_in=4,
            width_in=9,
            height_in=1,
            font_size_pt=30,
            color="#FFFFFF",
            align=PP_ALIGN.CENTER
        )
    # Logos
    if logo1_path:
        add_picture_safe(slide, logo1_path, left_in=0.4, top_in=6.6, height_in=0.6)
    if logo2_path:
        add_picture_safe(slide, logo2_path, left_in=8.0, top_in=6.6, height_in=0.6)

def add_agenda_slide(prs, assets, agenda_lines=None):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    add_full_slide_picture(slide, prs, assets.get("agenda"))
    sw_in = 10
    # Title
    add_title_box(
        slide,
        "Agenda",
        left_in=0.5,
        top_in=0.9,
        width_in=sw_in - 1,
        height_in=1.2,
        font_size_pt=52,
        color="#FFFFFF",
        align=PP_ALIGN.LEFT
    )
    if not agenda_lines:
        agenda_lines = ["Overview", "Key updates by product", "Timeline & rollout status", "Q&A"]
    top = 2.4
    for line in agenda_lines:
        add_text_box(
            slide,
            f"• {line}",
            left_in=0.5,
            top_in=top,
            width_in=sw_in - 1,
            height_in=0.5,
            font_size_pt=26,
            color="#FFFFFF",
            align=PP_ALIGN.LEFT
        )
        top += 0.6

def add_separator_slide(prs, assets, title):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    add_full_slide_picture(slide, prs, assets.get("separator"))
    sw_in = 10
    add_title_box(
        slide,
        title,
        left_in=0.5,
        top_in=3.2,
        width_in=9,
        height_in=1.5,
        font_size_pt=56,
        color="#FFFFFF",
        align=PP_ALIGN.CENTER,
    )

def add_conclusion_slide(prs, assets, links):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    add_full_slide_picture(slide, prs, assets.get("conclusion"))
    sw_in = 10
    add_title_box(
        slide,
        "Final Thoughts",
        left_in=0.5,
        top_in=0.9,
        width_in=9,
        height_in=1.2,
        font_size_pt=52,
        color="#FFFFFF",
        align=PP_ALIGN.CENTER,
    )
    top = 2.4
    for text, url in links:
        add_text_box(
            slide,
            f"{text}: {url}",
            left_in=0.5,
            top_in=top,
            width_in=9,
            height_in=0.5,
            font_size_pt=22,
            color="#FFFFFF",
            align=PP_ALIGN.LEFT
        )
        top += 0.6

def add_thankyou_slide(prs, assets):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    add_full_slide_picture(slide, prs, assets.get("thankyou"))

def add_item_slide(self, prs, item, month_str, assets, rail_left_in=0, rail_width_in=3):
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        # Implement item slide
        pass