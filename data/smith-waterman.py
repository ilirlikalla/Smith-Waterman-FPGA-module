## Smith-waterman algorithm with affine gaps
## author: Ilir Likalla


def localalignment(P, T):
    bases = ['A','C','G','T'] ## alphabet
    mismatch= -4
    match= 5
    gap_open= -12
    gap_extend= -4
    M= []
    I= []
    for i in range(len(P)+1):   ## initialise matrices
        M.append([0]*(len(T)+1))
        I.append([0]*(len(T)+1))
    
