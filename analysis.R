library(hgu133a2.db)
ls("package:hgu133a2.db")
ids <- toTable(hgu133a2SYMBOL) 
head(ids) 
a <- read.csv(file = "./GSE30529_series_matrix.csv")
GSE <- "GSE30529"


group <- gsub(".*: ","",as.character(a[43,2:ncol(a)])) 
group[grep("DKD",group)] <- "DKD"
b <- a[-grep("!",a[,1]),];b <- b[-1,]
c <- b[,-1];rownames(c) <- b[,1]
colnames(c) <- c[1,];c <- c[-1,]
d <- as.data.frame(apply(c, 2, as.numeric));rownames(d) <- rownames(c)

ids <- ids[match(rownames(d),ids$probe_id),]
ids$median=apply(d,1,median) 
ids=ids[order(ids$symbol,ids$median,decreasing = T),]
ids=ids[!duplicated(ids$symbol),]

d$probe_id <- rownames(d)
data <- merge(ids,d,by="probe_id")
rownames(data) <- data$symbol;data <- data[,-c(1:3)]
save(group,data,file = "GSE30529_cleanData.Rdata")

DEmedian_fun <- function(ExM,C1,C2){
  P.Value = padj = logFC = FoldChange = Mean1 = Mean2 = matrix(0, nrow(ExM), 1)
  for(i in 1:nrow(ExM)){
    P.Value[i, 1] = p.value = t.test(ExM[i, C1], ExM[i, C2])$p.value
    # FoldChange[i, 1] = Fold.Change = mean(ExM[i, C1]) / mean(ExM[i, C2])
    Mean1[i, 1] = mean(ExM[i, C1]);Mean2[i, 1] = mean(ExM[i, C2])
    
    logFC[i, 1] <- Mean1[i, 1] - Mean2[i, 1]
    FoldChange[i, 1] <- ifelse(logFC[i, 1]>0,
                               FoldChange[i, 1] <- 2^(logFC[i, 1]),
                               FoldChange[i, 1] <- -2^(-(logFC[i, 1])))
  }
  padj = p.adjust(as.vector(P.Value), "fdr", n = length(P.Value))
  result = data.frame(FoldChange,
                      logFC, P.Value, padj, 
                      row.names = rownames(ExM))
  return(result)
}
ExM <- as.matrix(data);rownames(ExM) <- rownames(data);colnames(ExM) <- colnames(data)
C1 <- (1:ncol(data))[group=="DKD"];C2 <- (1:ncol(data))[group=="control"]
tT <- DEmedian_fun(ExM,C1,C2)
tT <- cbind(rownames(tT),tT);colnames(tT)[1] <- "gene"

write.table(tT,file = paste0("./",GSE,"_foldchange.txt"),sep = "\t",quote = F,row.names = F)
library(ggrepel);library(ggplot2)

rt <- tT
rt$Condition=ifelse(rt$logFC>= 1.5 & rt$P.Value<=0.05,"up",
                    ifelse(rt$logFC<= -1.5 & rt$P.Value<=0.05,"down","normal"))

p <-ggplot(data=rt, 
           aes(x=logFC, y=-log10(P.Value), colour=Condition, size=Condition)) + 
  geom_point(alpha=1)  +  
  scale_y_continuous(breaks = seq(-20,20,5))+
  scale_size_manual(values = c(2,1.2,2))+
  
  xlab("logFC") + ylab("-log10(P Value)")+
  geom_hline(yintercept=-log10(0.05),linetype=4)+
  geom_vline(xintercept=c(-1.5,1.5),linetype=4)+
  
  annotate("text",x=-3.5,y=8,color="black",size=8,
           label=GSE)+
  
  geom_text_repel( data = rt[rt$gene=="CLU",],
                   aes(label = gene),
                   box.padding = 1, max.overlaps = Inf,
                   size = 7,color = "black",
                   segment.color = "black", show.legend = FALSE ,
                   nudge_x = 1,
                   segment.size = 0.4)+#??????????????????????????????
  
  
  scale_color_manual(values=c('up'='red','down'='blue','normal'='black'))+
  theme_minimal()+
  theme(panel.grid.minor= element_blank(), #element_line(color="#D8D8D8",size=.7),
        panel.grid.major=element_blank(), #element_line(color="#D8D8D8",size=.7),
        panel.border = element_rect(colour = "black", fill=NA, size=1),
        panel.background=element_rect(fill=NA,color = NA),
        
        
        legend.position = "none",
        axis.ticks = element_line(colour = "black",size=1),
        axis.ticks.length =unit(.2,"cm"),
        axis.line = element_line(colour = "black"),
        axis.text.x = element_text(size=16,colour = "black"),
        axis.text.y = element_text(size=17,colour = "black"),
        
        axis.title.x = element_text(size=25,colour = "black"),
        axis.title.y = element_text(size=25,colour = "black"),
        plot.margin=unit(c(1,1,1,1), "cm") ) + # 
  coord_cartesian(xlim=c(-4,4))
p


pdf(file=paste(GSE,"_volcano.pdf",sep = ""),width = 10,height = 8)
plot(p)
dev.off()