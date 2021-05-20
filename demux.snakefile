import sys
import itertools
import os
import collections
import json
import glob

configfile: "config.yaml"

f = open("SampleSheet.csv", 'r')
NAMES ={}
SAMPLES =[]
TARGET = []
TARGET_BASE = []
LIBRARIES = []
lineno = 1

def has_duplicates(my_list):
    for index in range(len(my_list)):
        if index!=0: # check only from 2nd element onwards
            item = my_list[index] # get the current item
            if item in my_list[:index]: # check if current item is in the beginning of the list uptill the current element
                return True # duplicate exist
    return False # duplicate does not exist

for line in f:
#        if 'Adapter' in line:
#            sys.exit("Please remove adaptor sequence from SampleSheet.csv")
        if 'Sample_ID' in line:
            column = line.split(",")
            sampleID    =column.index('Sample_ID')
            sampleName  =column.index('Sample_Name')
            libraryID   =column.index('Sample_Project')
            for line in f:
                column = line.split(",")
                SAMPLES += [column[sampleID]]
                NAMES[column[sampleID]] = column[sampleName]
                LIBRARIES += [column[libraryID]]
                LIBRARIES = list(filter(None, LIBRARIES))
                if (has_duplicates(SAMPLES) == False) and (len(LIBRARIES) > 0):
                    # placeholder for demultiplex with library folder
                    TARGET += [column[sampleID]+"_S"+str(lineno)+"_R1_001"]
                    TARGET += [column[sampleID]+"_S"+str(lineno)+"_R2_001"]
                    TARGET_BASE += [column[sampleID]+"_S"+str(lineno)]
                    lineno = lineno + 1
                elif (has_duplicates(SAMPLES) == False) and (len(LIBRARIES) == 0):
                    TARGET += [column[sampleID]+"_S"+str(lineno)+"_R1_001"]
                    TARGET += [column[sampleID]+"_S"+str(lineno)+"_R2_001"]
                    TARGET_BASE += [column[sampleID]+"_S"+str(lineno)]
                    lineno = lineno + 1

IDS = tuple(TARGET)
R1IDS = tuple(TARGET_BASE)
# LIBRARY_IDS = tuple(list(set(LIBRARIES)))


rule all:
    input:
        "multiqc_report.html"

rule demultiplex:
    input:
        samplesheet = "SampleSheet.csv"
    output:
        flag = "demultiplexed_reads/bcl2fastq.SUCCESS",
        all = expand("demultiplexed_reads/{sample}.fastq.gz", sample = IDS),
    threads: 8
    params:
        runfolder = config["runfolder"],
        dir = "demultiplexed_reads",
    shell:
        "ml purge && ml bcl2fastq2/2.20.0-intel-2019a;"
        "bcl2fastq "
        "    --runfolder-dir {params.runfolder}"
        "    --output-dir {params.dir}"
	"    --mask-short-adapter-reads 0"
        "    --interop-dir {params.dir}/InterOp "
        "    --sample-sheet {input} "
        "    --loading-threads {threads}"
        "    --processing-threads {threads} "
        "    --writing-threads {threads} "
        "    --barcode-mismatches 0 "
        "    --no-lane-splitting "
        "    --fastq-compression-level 6 "
        "    2>&1 | tee bcl2fastq.log && touch {output.flag} && "
        "    find {params.dir} -iname *gz -exec mv {{}} {params.dir} \;"

rule fastqc:
    input:
        flag = "demultiplexed_reads/bcl2fastq.SUCCESS",
        fq1 = "demultiplexed_reads/{sample}_R1_001.fastq.gz",
        fq2 = "demultiplexed_reads/{sample}_R2_001.fastq.gz"
    output:
        fq1 = "demultiplexed_reads/{sample}_R1_001_fastqc.html",
        fq2 = "demultiplexed_reads/{sample}_R2_001_fastqc.html"
    run:
        shell("""
        ml purge && ml FastQC/0.11.9-Java-11;
        fastqc {input.fq1} 
        fastqc {input.fq2} 
        """)

rule multiqc:
    input:
        expand("demultiplexed_reads/{sample}_R1_001_fastqc.html", sample = R1IDS),
    output:
        report("multiqc_report.html")
    shell:
        "ml purge && ml MultiQC/1.9-intel-2020a-Python-3.8.2; "
        "multiqc -f . ;"
        "mkdir -p snakejob_logs ;"
        "mv snakejob.* snakejob_logs"
