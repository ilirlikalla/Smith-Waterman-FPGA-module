# author: Ilir Likalla
import random

random.seed()

def genStrip(number, length, filename):
	base=['A', 'C','T','G']
	reads= []
	f= open(filename,'w')
	for j in range(0,number):
		ADN=''
		for i in range(0,length):
			ADN+=(base[random.randint(0,3)])
		reads.append(ADN)
		if(j==0):
			f.write('>query\n')
		else:
			f.write('>db'+str(j)+'\n')
		f.write(ADN+'\n')
		print(ADN)
	return reads

reads= genStrip(80, 128, "data80.fa")
##for i in range(0,10):
##    l=random.randint(8,12)
##    s=random.randint(0,len(ADN)-l)    
##    reads.append(ADN[s:s+l])
##print('reads:',reads)
