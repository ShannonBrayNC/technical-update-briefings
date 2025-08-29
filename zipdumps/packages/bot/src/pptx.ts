import PptxGenJS from "pptxgenjs";

export async function buildSingleSlide(options: {
  title: string;
  explanation: string;
  product?: string;
  status?: string;
}) {
  const pptx = new PptxGenJS();
  pptx.author = "Briefings Bot";
  pptx.company = "Technical Update Briefings";
  pptx.title = options.title;

  const slide = pptx.addSlide();
  slide.addText(options.title, { x: 0.5, y: 0.5, w: 9, h: 0.8, fontSize: 24, bold: true });
  const subtitle = [options.product, options.status].filter(Boolean).join(" · ");
  if (subtitle) slide.addText(subtitle, { x: 0.5, y: 1.2, w: 9, h: 0.5, fontSize: 14 });
  slide.addText(options.explanation, { x: 0.5, y: 1.8, w: 9, h: 4.5, fontSize: 14, valign: "top" });

  const buf = await pptx.write("nodebuffer");
  return Buffer.from(buf);
}
