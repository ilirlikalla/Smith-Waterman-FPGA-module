import swalign
import io

filename = "data1.fa"

# open read's data file:
data= open(filename,'r')

if data.closed:
    print("couldn't open "+filename+'\n')

# get the reads:
q= False    # query flag
t= False    # target flag
reads= []
lines = data.readlines()
for l in lines:
    if(l=='>query\n'):
        q= True         
    elif(q):
        query= l[:-1]   # remove LF character
        q= False
    elif(l[0]=='>'):
        t= True
    elif(t):
        reads.append(l[:-1])
        t= False
data.close()

# configure the aligner:
match = 5
mismatch = -4
gap_penalty = -12
gap_extension_penalty = -4
scoring = swalign.NucleotideScoringMatrix(match, mismatch)
sw = swalign.LocalAlignment(scoring,gap_penalty, gap_extension_penalty)  # you can also choose gap penalties, etc...

# calculate alignment for each read against the query:
out = open('sw_testing.txt','w');
i=1;
results= []
for r in reads:
    alignment = sw.align(r,query)
    out.write('\n##\n=========== db'+str(i)+': ============\n')
    alignment.dump(None,out )
    results.append(['db'+str(i),str(alignment.score)])
    out.write('\n============================\n')
    i= i+1;
print(results)
for r in results:
    out.write(r[0]+':\t'+r[1]+'\n')

out.close()
