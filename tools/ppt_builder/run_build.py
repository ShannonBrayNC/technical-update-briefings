def build(
    inputs,
    output_path,
    month,
    assets,
    template=None,
    rail_width=3.5,
    conclusion_links=None
):
    """
    Build a PowerPoint presentation.
    
    Parameters:
    - inputs: list of input HTML files
    - output_path: output PPTX filename
    - month: month string label
    - assets: dict of style assets and images
    - template: optional existing PPTX to use as template
    - rail_width: width of the side rail
    - conclusion_links: optional list of (text, url) pairs
    """
    # TODO: Implement your slide creation logic here
    print("build() called with:")
    print(f"  inputs: {inputs}")
    print(f"  output_path: {output_path}")
    print(f"  month: {month}")
    print(f"  assets: {assets}")
    print(f"  template: {template}")
    print(f"  rail_width: {rail_width}")
    print(f"  conclusion_links: {conclusion_links}")

    # For now, just create an empty presentation and save
    from pptx import Presentation
    prs = Presentation()
    prs.save(output_path)
    print(f"Saved empty PPTX to {output_path}")