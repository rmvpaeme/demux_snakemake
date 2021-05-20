ml snakemake/5.2.4-foss-2018b-Python-3.6.6
ml pygraphviz/1.5-foss-2018b-Python-3.6.6

PipelineDir="/scratch/gent/vo/000/gvo00027/projects/demux/demultiplex_snakemake"
snakefile="${PipelineDir}/demux.snakefile"
clusterTime="${PipelineDir}/clusterTime.json"

snakemake -s ${snakefile} --cluster-config ${clusterTime} --cluster "qsub -V -l nodes=1:ppn={cluster.ppn} -l walltime={cluster.walltime} " --jobs 300 --rerun-incomplete

