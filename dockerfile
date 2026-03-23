FROM ubuntu:22.04

# --------------------------
# Install required tools
# --------------------------
RUN apt-get update && apt-get install -y \
    wget curl unzip gzip \
    bwa samtools bcftools fastqc \
    sra-toolkit \
    default-jre \
    && rm -rf /var/lib/apt/lists/*

# --------------------------
# Set working directory
# --------------------------
WORKDIR /data

# --------------------------
# Set default number of threads
# --------------------------
ENV THREADS=4

# --------------------------
# Download reference genome and index it
# --------------------------
RUN wget -O GRCh38.fa.gz \
    https://ftp.ensembl.org/pub/release-109/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz && \
    gunzip GRCh38.fa.gz && \
    bwa index GRCh38.fa


# --------------------------
# Default command: interactive shell
# --------------------------
CMD ["/bin/bash"]




#!/bin/bash
# pipeline.sh

# Set SRR accessions
SRRS=("SRR22044200" "SRR22044199")

for SRR in "${SRRS[@]}"; do
    echo "Processing $SRR with $THREADS threads..."

    # Step 1: Download FASTQ (paired-end)
    fasterq-dump $SRR -O /data --split-files --gzip --threads $THREADS

    # Step 2: Quality Check

    fastqc /data/${SRR}_1.fastq.gz -o /data
    fastqc /data/${SRR}_2.fastq.gz -o /data

    # Step 3: Alignment

    bwa mem -t $THREADS /data/GRCh38.fa \
        /data/${SRR}_1.fastq.gz /data/${SRR}_2.fastq.gz > /data/$SRR.sam

    # Step 4: BAM processing
    samtools view -@ $THREADS -Sb /data/$SRR.sam | samtools sort -@ $THREADS -o /data/$SRR.bam
    samtools index /data/$SRR.bam

    # Step 5: Variant Calling
    bcftools mpileup --threads $THREADS -f /data/GRCh38.fa /data/$SRR.bam | \
    bcftools call -mv -o /data/$SRR.vcf

    echo "$SRR pipeline complete!"
done
