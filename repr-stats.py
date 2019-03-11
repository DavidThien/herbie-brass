# Note this file must be run with all the lambdas in 'brass-output.txt'
# changed to 'lambda'

# Note start program is not checked to see if it was the best program
# This is because without looking at the bit diifference, it is a misleading
# stat; Herbie will optimize based on a few points a better program which will
# be slightly worse when we calculate the final error score

f = open('brass-output.txt')

double_run = []
single_run = []
posits_run = []

def append_val(l, val):
    if '#f' in val:
        l.append(100.0) # Represent as more error than possible
    else:
        l.append(float(val))

index = 0
for line in f:
    if index == 7:
        nums = line.split('|')
        vals = []
        for i in range(3, 6):
            append_val(vals, nums[i])
        double_run.append(vals)
    elif index == 8:
        nums = line.split('|')
        vals = []
        for i in range(3, 6):
            append_val(vals, nums[i])
        single_run.append(vals)
    elif index == 9:
        nums = line.split('|')
        vals = []
        for i in range(3, 6):
            append_val(vals, nums[i])
        posits_run.append(vals)
        index = -1
    index = index + 1

double_double_best = 0
double_single_best = 0
double_posits_best = 0
double_non_unique_best = 0

for t in double_run:
    best = min(t)
    best_copy = list(t)
    best_copy.sort()
    if best_copy[0] == best_copy[1]:
        double_non_unique_best = double_non_unique_best + 1
    else:
        if t[0] == best:
            double_double_best = double_double_best + 1
        if t[1] == best:
            double_single_best = double_single_best + 1
        if t[2] == best:
            double_posits_best = double_posits_best + 1

single_double_best = 0
single_single_best = 0
single_posits_best = 0
single_non_unique_best = 0

for t in single_run:
    best = min(t)
    best_copy = list(t)
    best_copy.sort()
    if best_copy[0] == best_copy[1]:
        single_non_unique_best = single_non_unique_best + 1
    else:
        if t[0] == best:
            single_double_best = single_double_best + 1
        if t[1] == best:
            single_single_best = single_single_best + 1
        if t[2] == best:
            single_posits_best = single_posits_best + 1

posits_double_best = 0
posits_single_best = 0
posits_posits_best = 0
posits_non_unique_best = 0

for t in posits_run:
    best = min(t)
    best_copy = list(t)
    best_copy.sort()
    if best_copy[0] == best_copy[1]:
        posits_non_unique_best = posits_non_unique_best + 1
    else:
        if t[0] == best:
            posits_double_best = posits_double_best + 1
        if t[1] == best:
            posits_single_best = posits_single_best + 1
        if t[2] == best:
            posits_posits_best = posits_posits_best + 1

print('Total tests: ' + str(len(double_run)))
print('')
print('Double nonunique best tests: ' + str(double_non_unique_best))
print('Double double program is best: ' + str(double_double_best))
print('Double single program is best: ' + str(double_single_best))
print('Double posits program is best: ' + str(double_posits_best))
print('')
print('Single nonunique best tests: ' + str(single_non_unique_best))
print('Single double program is best: ' + str(single_double_best))
print('Single single program is best: ' + str(single_single_best))
print('Single posits program is best: ' + str(single_posits_best))
print('')
print('Posits nonunique best tests: ' + str(posits_non_unique_best))
print('Posits double program is best: ' + str(posits_double_best))
print('Posits single program is best: ' + str(posits_single_best))
print('Posits posits program is best: ' + str(posits_posits_best))
