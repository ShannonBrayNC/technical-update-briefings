# layout.py

from pptx.util import Pt
from pptx.enum.text import PP_ALIGN
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from typing import Union
import os

def add_title_box(
    slide,
    text,
    *,
    left_in,
    top_in,
    width_in,
    height_in,
    font_size_pt=60,
    bold=True,
    color: Union[str, RGBColor] = "#FFFFFF",
    align=PP_ALIGN.CENTER
):
    # function body indented 4 spaces
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
    from pptx.dml.color import RGBColor
    r.font.color.rgb = RGBColor.from_string(color)

def add_text_box(
        slide, 
        text, *, 
        left_in, 
        top_in, 
        width_in, 
        height_in, 
        font_size_pt=18, 
        bold=False, 
        color="#FFFFFF", 
        align=PP_ALIGN.LEFT
        ):
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


class Layout:
    def __init__(self, assets):
        self.assets = assets

    def add_cover_slide(self, prs, assets, content):
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        add_full_slide_picture(slide, prs, assets.get("cover"))
        # Extract from content
        cover_title = content.get('title', 'Title')
        cover_dates = content.get('dates', '')
        # use the existing add_title_box() logic
        add_title_box(
            slide,
            cover_title,
            left_in=0.5,
            top_in=2,
            width_in=9,
            height_in=2,
            font_size_pt=52,
            color="#FFFFFF",
            align=PP_ALIGN.CENTER
        )
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
            # Implement your style & slide logic here
            pass

    def add_agenda_slide(self, prs, assets, agenda_lines=None):
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        # Implement agenda slide
        pass

    def add_separator_slide(self, prs, assets, title):
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        # Implement separator slide
        pass

    def add_conclusion_slide(self, prs, assets, links):
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        # Implement conclusion slide
        pass

    def add_thankyou_slide(self, prs, assets):
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        # Implement thank you slide
        pass

    def add_item_slide(self, prs, item, month_str, assets, rail_left_in=0, rail_width_in=3):
        slide = prs.slides.add_slide(prs.slide_layouts[6])
        # Implement item slide
        pass