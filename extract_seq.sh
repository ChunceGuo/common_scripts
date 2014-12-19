#!/bin/bash
if [ $# -lt 2 ] ; then
echo "extract_seq.sh <gff> <fasta>"
exit 0
fi

GFF="$1"
FASTA="$2"
GBASE=$(basename ${GFF%.*})

module load bedtools

CODW="/data004/software/GIF/packages/codonW/1.4.4"

awk '$3=="CDS" {print $0}' ${GFF} > ${GBASE}_CDS.gff
bedtools getfasta -fi ${FASTA} -bed ${GBASE}_CDS.gff -fo ${GBASE}_CDS.fasta
${CODW}/codonw ${GBASE}_CDS.fasta ${GBASE}_GC3.txt ${GBASE}_GC3.blk -nomenu -nowarn -noblk -gc3s
sed -i -e 's/ //g' -e 's/:/\t/g' -e 's/-/\t/g' ${GBASE}_GC3.txt
awk '{print $0, $3-$2+1}' ${GBASE}_GC3.txt | awk '($NF % 3) == 0' | awk '$NF >= 300' > ${GBASE}_filtered.txt

for chr in $(cut -f 1 ${GBASE}_filtered.txt |sort | uniq); do
  grep -w "${chr}" ${GBASE}_filtered.txt | sort -k 3,3 -n | awk '{print NR"\t"$4*100}'> ${GBASE}_${chr}.txt
  sed -i '1 i Order\tChr'${chr}'' ${GBASE}_${chr}.txt
  lines=$(wc -l ${GBASE}_${chr}.txt | cut -d " " -f 1);
  if [ "${lines}" -gt "20" ]; then
cat <<CMD1 >> rplots_pdf.R
dv <- read.table("${GBASE}_${chr}.txt", header=1)
gc3pc = dv[,2]
coef15 = 1/15
ma15 = filter(gc3pc, rep(coef15, 15), sides=1)
jpeg("${GBASE}_Chr${chr}.jpg", width=5, height=5, units="in", res=500)
plot(gc3pc, type="l", main="Chromosome ${chr}", xlab="Gene number", ylab="GC3 %", col="white")
lines(ma15, col="black")
dev.off()
CMD1
else
  echo "#skipping Chr${chr}"
fi
done

Rscript rplots_pdf.R;
mkdir -p ${GBASE}_plots
mv *.jpg ${GBASE}_plots/
