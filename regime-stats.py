import matplotlib.pyplot as plt

# Numbers here are the Herbie improvement on increased regimes over original
# output in bits
# stats = [21.099, 14.183, 0.0, 0.0, 30.507, 31.285, 46.772, 31.860,
         # 31.158, 45.393, 30.986, 44.431, 29.155, 33.302, 29.037, 32.003,
         # 20.397, 31.261, 31.343, 0.0, 45.6006, 5.958, 0.0, 0.0, 31.669,
         # 11.822, 20.731, 21.222]

test_name = []
base_error = []
base_output_error = []
expanded_base_error = []
expanded_error = []
expanded_output_error = []
herbie_improvement = []

f = open('regimes-output.txt')

for line in f:
    if 'Now running test' in line:
        test_name.append(line.split(': ')[1][:-1])
    elif 'Base regime error improvement' in line:
        nums = line.split(': ')[1].split(' -> ')
        base_error.append(float(nums[0]))
        base_output_error.append(float(nums[1]))
    elif 'Base output error' in line:
        expanded_base_error.append(float(line.split(': ')[1]))
    elif 'Expanded regime error improvement' in line:
        nums = line.split(': ')[1].split(' -> ')
        expanded_error.append(float(nums[0]))
        expanded_output_error.append(float(nums[1]))
    elif 'Herbie improved this expanded regime by' in line:
        herbie_improvement.append(float(line.split(' ')[6]))

assert(len(test_name) == len(base_error)
                      == len(base_output_error)
                      == len(expanded_base_error)
                      == len(expanded_error)
                      == len(expanded_output_error)
                      == len(herbie_improvement))

combined = []

for i in range(len(test_name)):
    combined.append((test_name[i], base_error[i], base_output_error[i],
                     expanded_base_error[i], expanded_error[i],
                     expanded_output_error[i], herbie_improvement[i]))

combined.sort(key=lambda x: x[4])

print('Test Name')
name = []
for x in combined:
    name.append(x[0])
print(name)
print('')

print('Expanded Error')
exp_err = []
for x in combined:
    exp_err.append(x[4])
print(exp_err)
print('')

print('Expanded Base Error')
exp_base_err = []
for x in combined:
    exp_base_err.append(x[3])
print(exp_base_err)
print('')

print('Expanded Output Error')
exp_out_err = []
for x in combined:
    exp_out_err.append(x[5])
print(exp_out_err)
print('')

"""
print('Test Names')
print(test_name)
print('')

print('Base Errors')
print(base_error)
print('')

print('Base Output Errors')
print(base_output_error)
print('')

print('Expanded Base Errors')
print(expanded_base_error)
print('')

print('Expanded Errors')
print(expanded_error)
print('')

print('Expanded Output Errors')
print(expanded_output_error)
print('')

print('Herbie Improvements')
print(herbie_improvement)
print('')
"""
