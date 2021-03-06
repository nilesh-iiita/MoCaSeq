#!/usr/bin/Rscript

##########################################################################################
##
## CNV_RunCopywriter.R
##
## Run Copywriter on matched tumour-normal .bam-files using 20kb windows.
##
##########################################################################################

args <- commandArgs(TRUE)

name = args[1]
species = args[2]
threads = args[3]
runmode = args[4]
genome_dir = args[5]
centromere_file <- args[6]
varregions_file <- args[7]
resolution <- args[8]
type <- args[9]

if (resolution=="NULL") { resolution=20000 } 

library(CopywriteR)
library(GenomeInfoDb)
library(naturalsort)
library(GenomicRanges)

tumor_bam = paste(name,"/results/bam/",name,".Tumor.bam",sep="")
normal_bam = paste(name,"/results/bam/",name,".Normal.bam",sep="")

if (runmode == "MS") {
	sample.control = data.frame(samples=c(normal_bam,tumor_bam),controls=c(normal_bam,normal_bam))
}

if (runmode == "SS") {
	if (types == "Tumor") {
		sample.control = data.frame(samples=c(tumor_bam),controls=c(tumor_bam))
	} else if (types == "Normal") {
		sample.control = data.frame(samples=c(normal_bam),controls=c(normal_bam))
	}
}

resolution=as.numeric(as.character(resolution))/1000

if (species == "Human") {
	reference_files = paste(genome_dir,"/hg38_",resolution,"kb",sep="")
} else if (species == "Mouse") {
	reference_files = paste(genome_dir,"/mm10_",resolution,"kb",sep="")
}

bp.param = SnowParam(workers = threads, type = "SOCK")

CopywriteR(sample.control = sample.control,
             destination.folder = file.path(paste(name,"/results/Copywriter/",sep="")),
             reference.folder = file.path(reference_files),
             bp.param = bp.param)

log2.reads=read.table(paste0(name,"/results/Copywriter/CNAprofiles/log2_read_counts.igv"), header=T, sep="\t",check.names=FALSE)

file.copy(paste0(name,"/results/Copywriter/CNAprofiles/log2_read_counts.igv"),paste0(name,"/results/Copywriter/CNAprofiles/log2_read_counts_backup.igv"), overwrite=T)

log2.reads.GR=GRanges(log2.reads$Chromosome, IRanges(log2.reads$Start, log2.reads$End),Feature=as.character(log2.reads$Feature), Normal=log2.reads[,5],Tumor=log2.reads[,6])

# remove regions with increased variability for mice and centromere regions for humams
if (species == "Human")
{
	filter=read.delim(centromere_file)
	flankLength=5000000
}
if (species == "Mouse")
{
	filter=read.delim(varregions_file)
	flankLength=0
}

colnames(filter)[1:3] <- c("Chromosome","Start","End")
filter$Start <- filter$Start - flankLength
filter$End <- filter$End + flankLength
filter=GRanges(filter$Chromosome, IRanges(filter$Start, filter$End))

hits <- findOverlaps(query = log2.reads.GR, subject = filter)
ind <- queryHits(hits)
message("Removed ", length(ind), " bins near centromeres.")
log2.reads.GR=(log2.reads.GR[-ind, ])

log2.reads.fixed=as.data.frame(log2.reads.GR)
log2.reads.fixed=log2.reads.fixed[,c("seqnames", "start", "end", "Feature", "Normal","Tumor")]
colnames(log2.reads.fixed)=c("Chromosome", "Start", "End", "Feature",paste0("log2.",name,".Normal.bam"),paste0("log2.",name,".Tumor.bam"))

write.table(log2.reads.fixed,paste0(name,"/results/Copywriter/CNAprofiles/log2_read_counts.igv"), sep="\t", quote=F, row.names=F,col.names=T)

plotCNA(destination.folder = file.path(paste(name,"/results/Copywriter/",sep="")))