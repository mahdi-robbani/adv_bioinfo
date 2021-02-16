# Learn how to correct for batch effect.
# Learn how to identify differentially expressed genes across batch 
load('inputData.Rdata')
source("shared_functions.R")

# Section 2: Using Combat to normalize batch effect.

sampleTable$caste[which(sampleTable$caste == 'Minor_worker')] = 'Worker'  # For simplity, we treat minor worker in A.echinator as worker caste
normal_ant = which(sampleTable$species %in% c("Aech",'Mpha',"Lhum",'Sinv',"Lnig"))
ortholog_exp.ant = ortholog_counts[,normal_ant]
sampleTable.ant = sampleTable[normal_ant,]
ortholog_exp.ant = ortholog_exp.ant[!apply(ortholog_exp.ant, 1, anyNA),]  #Removed genes showing NA (e.g. without expression)
ortholog_exp.ant.norm = log2(normalize.quantiles(ortholog_exp.ant)+1)
colnames(ortholog_exp.ant.norm) = colnames(ortholog_exp.ant)
rownames(ortholog_exp.ant.norm) = rownames(ortholog_exp.ant)
ortholog_exp.ant.norm = ortholog_exp.ant.norm[apply(ortholog_exp.ant.norm, 1, 
                                                    FUN = function(x) return(var(x, na.rm = T) > 0)),] 

# Removing colony we also remove the effect of the species (we can also change colony with species and remove species only)
batch = droplevels(sampleTable.ant$colony) # Normalization for species identity (or colony).
modcombat = model.matrix(~1, data = sampleTable.ant)
# Empirical based method to removed the effect of species identity
combat.ortholog_exp.ant = ComBat(dat=ortholog_exp.ant.norm, batch=batch, mod=modcombat,                  # Use this for the normalized network
                                 mean.only = F, par.prior=TRUE, prior.plots=FALSE)

sampleDists.combat = as.dist(1 - cor(combat.ortholog_exp.ant,method = 's'))
pheatmap(sampleDists.combat,annotation_col = sampleTable.ant[,c(1:3)], 
         annotation_colors = ann_colors,
         color = colors) 
var.gene = order(apply(combat.ortholog_exp.ant,1,var),decreasing = T)[c(1:1000)]
ortholog_exp.combat.pca <- PCA(t(combat.ortholog_exp.ant[var.gene,]),ncp = 4, graph = FALSE)

# Take a look at the amount of variations explained by each PC.
fviz_eig(ortholog_exp.combat.pca, addlabels = TRUE,main = 'Explained variance for each PC')

pca.combat.var = ortholog_exp.combat.pca$eig
pca.combat.data = cbind(ortholog_exp.combat.pca$ind$coord,sampleTable.ant)
ggplot(pca.combat.data, aes(x = Dim.1, y = Dim.2, color = caste, shape = species)) +
  geom_point(size=3) +
  coord_fixed()

# Questions:
# What is the dominant factor for PC 1? 
# The caste
# Does species identity play role in gene expression after normalization? How to explain?
# Answer: After we removed the species effect, how can the species be in the plot?  That's because there could be
# interaction between species and cast (in one species a certain gene is highly expressed in Gyne while in another
# species it might be highly express in the worker)
# PC 2 is reflecting species and cast interaction

# Section 3: Construction of co-expression network:
# See how different way of norm can influence network construction 
# (1 we use row data (quantile normalized but removed species and batch) still using batch effect and species effect inside)
# (2 data without species and batch effect)
sample_genes = sample(dim(ortholog_exp.ant.norm)[1], size = 100) # randomly sample 100 genes

gene_correlation = abs(cor(t(ortholog_exp.ant.norm[sample_genes,]),method = 's'))
gene_correlation = abs(cor(t(combat.ortholog_exp.ant[sample_genes,]),method = 's')) # <- I added that line
gene.dist = as.dist(1-gene_correlation)
pheatmap(gene.dist,show_rownames = F,show_colnames = F,color = colors_gene)

gene_connections = apply(gene_correlation,1,mean) # identify set of genes with high connection (compute the mean of correlation with other gene and identify the gene with highest connections with other genes)
gene_connections[order(gene_connections,decreasing = T)[c(1:10)]]
top_gene = names(gene_connections[order(gene_connections,decreasing = T)[1]])
gene_correlation[top_gene,order(gene_correlation[top_gene,],decreasing = T)[c(1:10)]] # top gene wigh highest connection
correlated_gene = names(gene_correlation[top_gene,order(gene_correlation[top_gene,],decreasing = T)])[2] # select the second cause the first is itself
gene_x = ortholog_exp.ant.norm[top_gene,]
gene_y = ortholog_exp.ant.norm[correlated_gene,]
plot(gene_x,gene_y,col = sampleTable.ant$species, pch = 20)
text(gene_x, gene_y, sampleTable.ant$species, cex=0.6, pos=4, col="black")
text(gene_x, gene_y, sampleTable.ant$caste, cex=0.6, pos=2, col="black")

# If we don't normalize for the species and batch effect, the network will be dominated by these non interesting pattern

# Code for the visualization of the network is on messanger MIA group

# Question: How many gene clusters are there in gene.dist.a? What about gene.dist.b?
# In order to identify gene modules associated with caste, should we use gene.dist.a or gene.dist.b? Why?

# Section 4: Identification of caste differentially expressed genes
ortholog_counts.ant = ortholog_counts[,normal_ant]
ortholog_counts.ant = ortholog_counts.ant[!apply(ortholog_counts.ant, 1, anyNA),]
ortholog_counts.ant.norm = matrix(as.integer(ortholog_counts.ant), ncol = dim(ortholog_counts.ant)[2],
                                  dimnames = list(rownames(ortholog_counts.ant),colnames(ortholog_counts.ant)))

target_species = 'Aech' # Can we test with "Mpha"? Just switch it with "Aech"
dds <- DESeqDataSetFromMatrix(ortholog_counts.ant.norm[,which(sampleTable.ant$species %in% target_species)], 
                              sampleTable.ant[which(sampleTable.ant$species %in% target_species),], 
                                ~ caste)        # Here we are subsetting 
                                                # -> if I add + colony after caste I see the effect of caste and colony
                                                #    the number will be higher, because if we consider the effect of colony too I have a stronger
                                                #    power 
dds = DESeq(dds) # Use dseq to read the expression matrix
res.aech = results(dds, contrast = c("caste",c("Gyne",'Worker')),alpha = 0.05)  # we teste caste between Gyne and Worker
summary(res.aech) # We can try to calculate the different number of coexpressed genes between species

# We replace the target species and we see how many upregulated genes in that species (we are only testing the caste effect in this model)

# Part1
# Assignemnt if we test the number of differentially expressed genes in each species (using caste) and then we plot the overlap between species, 
# return how many are overlapping between 2, 3, 4 species
# Then we test the number of differentially express genes with the new model (species and caste)
# try to explain the difference between these two (that one and only caste?)

# Part2
# Test if queens ant 

# Question
# Replace Aech with Mpha, Lhum, Sinv, or Lnig, how many DEGs are there for each of the species?
# Define DEGs as genes with adjusted Pvalue < 0.1, how many genes are shared across five ant species?

# Question:
# Can you model the expression level of genes as: Exp ~ species + caste?
# How many genes are differentially expressed under the new model?
# What about: Exp ~ species + caste + species:caste ?

# Homework: Include the two queenless ants, report the PCA result for expression normalzed for species batch.
# Optional Homework: We have used the correlation (distance) method to construct coexpression network for caste phenotype. We could also use factor analysis method.
#   If the first two PCs of the PCA (pca.combat.data) represent the genetic regulatory network for caste phenotype, can you extract them and examine its expression levels on the queenless ants? (Hint: Wiki the link between PCA and SVD (http://www.iro.umontreal.ca/~pift6080/H09/documents/papers/pca_tutorial.pdf), learn how to extract eigenvectors and reconstruct original matrix).
# https://www.datacamp.com/community/tutorials/pca-analysis-r
# Note: Upload the codes, I will score it based on the codes for all the questions, including the homework.
# Note 2: If you would like to join our lab, try to finish the optional homework.