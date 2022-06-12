# rule start_ipython_sfacts:
#     params:
#         sfacts_dev_path=config["software-dev-path"]["sfacts"],
#     container:
#         config["container"]["sfacts"]
#     shell:
#         """
#         export PYTHONPATH="{params.sfacts_dev_path}"
#         ipython
#         """


# Same as sfacts, but with an environment defined by conda/sfacts.yaml
# rather than hard-coded into the container.
# This causes problems with GPU sfacts.
rule start_ipython_sfacts:
    container:
        config["container"]["mambaforge"]
    conda:
        "conda/sfacts.yaml"
    shell:
        """
        export PYTHONPATH="{config[software-dev-path][sfacts]}"
        ipython
        """


# rule start_jupyter_sfacts:
#     threads: config['MAX_THREADS']
#     params:
#         sfacts_dev_path=config["software-dev-path"]["sfacts"],
#         port=config["jupyter_port"],
#     container:
#         config["container"]["sfacts"]
#     shell:
#         """
#         export PYTHONPATH="{params.sfacts_dev_path}"
#         jupyter lab --port={params.port}
#         """


rule start_jupyter_sfacts:
    threads: config["MAX_THREADS"]
    params:
        port=config["jupyter_port"],
    container:
        config["container"]["mambaforge"]
    conda:
        "conda/sfacts.yaml"
    shell:
        """
        export PYTHONPATH="{config[software-dev-path][sfacts]}"
        jupyter lab --port={params.port} --notebook-dir nb/
        """


rule load_metagenotype_from_merged_gtpro:
    output:
        "{stem}.gtpro.mgen.nc",
    input:
        "{stem}.gtpro_combine.tsv.bz2",
    params:
        sfacts_dev_path=config["software-dev-path"]["sfacts"],
    container:
        config["container"]["sfacts"]
    shell:
        """
        export PYTHONPATH="{params.sfacts_dev_path}"
        python3 -m sfacts load --gtpro-metagenotype {input} {output}
        """


rule start_jupyter_sfacts2:
    threads: config["MAX_THREADS"]
    container:
        config["container"]["mambaforge"]
    conda:
        "conda/sfacts2.yaml"
    shell:
        """
        export PYTHONPATH="{config[software-dev-path][sfacts]}"
        jupyter lab --port="{config[jupyter_port]}" --notebook-dir nb/
        """

rule start_jupyter_sfacts3:
    threads: config["MAX_THREADS"]
    container:
        config["container"]["mambaforge"]
    conda:
        "conda/sfacts3.yaml"
    shell:
        """
        jupyter lab --port="{config[jupyter_port]}" --notebook-dir nb/
        """

rule filter_metagenotype:
    output:
        "{stem}.filt-poly{poly}-cvrg{cvrg}.mgen.nc",
    input:
        "{stem}.mgen.nc",
    wildcard_constraints:
        poly="[0-9]+",
        cvrg="[0-9]+",
    params:
        poly=lambda w: float(w.poly) / 100,
        cvrg=lambda w: float(w.cvrg) / 100,
    container:
        config["container"]["sfacts"]
    shell:
        """
        export PYTHONPATH="{config[software-dev-path][sfacts]}"
        python3 -m sfacts filter_mgen --min-minor-allele-freq {params.poly} --min-horizontal-cvrg {params.cvrg} {input} {output}
        """

rule subset_metagenotype:
    output: '{stem}.ss-g{num_positions}-block{block_number}-seed{seed}.mgen.nc'
    input: '{stem}.mgen.nc'
    params:
        seed=lambda w: int(w.seed),
        num_positions=lambda w: int(w.num_positions),
        block_number=lambda w: int(w.block_number),
    container:
        config["container"]["mambaforge"]
    conda:
        "conda/sfacts.yaml"
    shell:
        """
        export PYTHONPATH="{config[software-dev-path][sfacts]}"
        python3 -m sfacts sample_mgen \
                --random-seed {params.seed} \
                --num-positions {params.num_positions} \
                --block-number {params.block_number} \
                {input} \
                {output}
        """

rule sfacts_nmf_approximation:
    output: '{stem}.approx-nmf-s{strain_exponent}-seed{seed}.world.nc'
    input: '{stem}.mgen.nc'
    params:
        seed=lambda w: int(w.seed),
        strain_exponent=lambda w: float(w.strain_exponent) / 100,
        alpha_genotype=0.1,
    container:
        config["container"]["mambaforge"]
    conda:
        "conda/sfacts.yaml"
    shell:
        """
        export PYTHONPATH="{config[software-dev-path][sfacts]}"
        python3 -m sfacts nmf_init \
                --random-seed {params.seed} \
                --strain-sample-exponent {params.strain_exponent} \
                --alpha-genotype {params.alpha_genotype} \
                {input} \
                {output}
        """

rule sfacts_clust_approximation:
    output: '{stem}.approx-clust-thresh{thresh}-s{strain_exponent}-seed{seed}.world.nc'
    input: '{stem}.mgen.nc'
    params:
        seed=lambda w: int(w.seed),
        thresh=lambda w: float(w.thresh) / 100,
        strain_exponent=lambda w: float(w.strain_exponent) / 100,
    container:
        config["container"]["mambaforge"]
    conda:
        "conda/sfacts.yaml"
    shell:
        """
        export PYTHONPATH="{config[software-dev-path][sfacts]}"
        python3 -m sfacts clust_init \
                --verbose \
                --random-seed {params.seed} \
                --strain-sample-exponent {params.strain_exponent} \
                --thresh {params.thresh} \
                {input} \
                {output}
        """

rule fit_sfacts_strategy11:
    output:
        fit="{stem}.fit-sfacts11-s{strain_exponent}-seed{seed}.world.nc",
        hist="{stem}.fit-sfacts11-s{strain_exponent}-seed{seed}.loss_history"
    input:
        mgen="{stem}.mgen.nc",
        # init='{stem}.approx-nmf-s{strain_exponent}-seed{seed}.world.nc',
    wildcard_constraints:
        strain_exponent="[0-9]+",
        nposition="[0-9]+",
    params:
        strain_exponent=lambda w: float(w.strain_exponent) / 100,
        rho_hyper=1.0,
        rho_hyper2=1.0,
        gamma_hyper=1e-5,
        pi_hyper=0.2,
        pi_hyper2=0.2,
        model_name="model4",
        seed=lambda w: int(w.seed),
    resources:
        walltime_hr=2,
        pmem=5_000,
        mem_mb=5_000,
        device={0: "cpu", 1: "cuda"}[config["USE_CUDA"]],
        gpu_mem_mb={0: 0, 1: 5_000}[config["USE_CUDA"]],
    container:
        config["container"]["mambaforge"]
    conda:
        "conda/sfacts.yaml"
    shell:
        """
        export PYTHONPATH="{config[software-dev-path][sfacts]}"
        python3 -m sfacts fit -m {params.model_name}  \
                --verbose --device {resources.device} \
                --random-seed {params.seed} \
                --strain-sample-exponent {params.strain_exponent} \
                --optimizer-learning-rate 0.5 \
                --min-optimizer-learning-rate 1e-2 \
                --hyperparameters gamma_hyper={params.gamma_hyper} \
                    pi_hyper={params.pi_hyper} pi_hyper2={params.pi_hyper2} \
                    rho_hyper={params.rho_hyper} rho_hyper2={params.rho_hyper2} \
                --anneal-steps 2000 --anneal-wait 1000 --anneal-hyperparameters pi_hyper=1e-3 pi_hyper2=1e-3 \
                --history-outpath {output.hist} \
                -- {input.mgen} {output.fit}
        """

rule collapse_similar_strains:
    output: '{stem}.collapse-{thresh}.world.nc'
    input: '{stem}.world.nc'
    params:
        thresh=lambda w: float(w.thresh) / 100,
    container:
        config["container"]["mambaforge"]
    conda:
        "conda/sfacts.yaml"
    shell:
        """
        export PYTHONPATH="{config[software-dev-path][sfacts]}"
        python3 -m sfacts collapse_strains --discretized {params.thresh} {input} {output}
        """

rule export_sfacts_comm:
    output: '{stem}.comm.tsv'
    input: '{stem}.world.nc'
    container:
        config["container"]["mambaforge"]
    conda:
        "conda/sfacts.yaml"
    shell:
        """
        export PYTHONPATH="{config[software-dev-path][sfacts]}"
        python3 -m sfacts dump --community {output} {input}
        """


# NOTE: Hub-rule: Comment out this rule to reduce DAG-building time
# once it has been run for the focal group.
rule calculate_all_strain_depths:
    output:
        "data/{group}.a.{proc_stem}.gtpro.{fit_stem}.strain_depth.tsv"
    input:
        script="scripts/merge_all_strains_depth.py",
        species="data/{group}.a.{proc_stem}.gtpro.species_depth.tsv",
        strains=lambda w: [
            f"data/sp-{species}.{w.group}.a.{w.proc_stem}.gtpro.{w.fit_stem}.comm.tsv"
            for species in checkpoint_select_species_with_greater_max_coverage_gtpro(
                group=w.group, stem=w.proc_stem, cvrg_thresh=0.2, require_in_species_group=True,
            )
        ],
    params:
        args=lambda w: [
            f"{species}=data/sp-{species}.{w.group}.a.{w.proc_stem}.gtpro.{w.fit_stem}.comm.tsv"
            for species in checkpoint_select_species_with_greater_max_coverage_gtpro(
                group=w.group, stem=w.proc_stem, cvrg_thresh=0.2, require_in_species_group=True,
            )
        ],
    shell:
        """
        {input.script} {input.species} {output} {params.args}
        """
