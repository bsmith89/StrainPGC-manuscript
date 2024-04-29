rule sort_bib_from_raw:
    output:
        "doc/bibliography.bib",
    input:
        script="scripts/sort_bib.py",
        bib=["doc/bibliography_raw.bib"],
    conda: "conda/pandoc.yaml"
    shell:
        "python {input.script} {input.bib} > {output}"

rule render_pdf_to_png_imagemagick:
    output:
        "fig/{stem}.dpi{dpi}.png",
    input:
        "fig/{stem}.pdf",
    params:
        dpi=lambda w: int(w.dpi),
    shell:
        """
        convert -units PixelsPerInch -density {params.dpi} {input} {output}
        """



rule render_figure_to_pdf:
    output:
        "fig/{stem}_figure.pdf",
    input:
        "doc/static/{stem}_figure.svg",
    shell:
        """
        inkscape {input} --export-filename {output}
        """


rule build_manuscript_docx:
    output:
        "build/manuscript.docx",
    input:
        source="doc/manuscript/manuscript.md",
        bib="doc/bibliography.bib",
        template="doc/manuscript/example_style.docx",
        csl="doc/manuscript/citestyle.csl",
        figures=[
            "fig/concept_diagram_figure.dpi200.png",
            "fig/benchmarking_figure.dpi200.png",
            "fig/hmp2_diversity_figure.dpi200.png",
            "fig/pangenomics_figure.dpi200.png",
            "fig/ucfmt_figure.dpi200.png",
            "fig/accuracy_by_depth_figure.dpi200.png",
            "fig/genome_fraction_refs_figure.dpi200.png",
        ],
    conda: "conda/pandoc.yaml"
    shell:
        """
        pandoc --from markdown --to docx \
               --embed-resources --standalone --reference-doc {input.template} \
               --filter pandoc-crossref --csl {input.csl} --citeproc \
               --bibliography={input.bib} -s {input.source} -o {output}
        """


localrules:
    build_manuscript_docx,
