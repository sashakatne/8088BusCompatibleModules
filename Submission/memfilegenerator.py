# Random Memory init file generator for the memory and I/O devices 
# with specified width and number of units

import random

mem_address_width = 19
io_address_width = 16
num_units_mem = 2**mem_address_width
# num_units_io0 = 16
# num_units_io1 = 512
num_units_io0 = 2**io_address_width
num_units_io1 = 2**io_address_width
data_width = 8

def generate_memory_file(filename, num_units, data_width):
    with open(filename, 'w') as file:
        for _ in range(num_units):
            value = random.randint(0, 2**data_width - 1)
            file.write(f"{value:02X}\n")  # Write the value in hex format

generate_memory_file("memory0_init.mem", num_units_mem, data_width)
generate_memory_file("memory1_init.mem", num_units_mem, data_width)
generate_memory_file("io_device0_init.mem", num_units_io0, data_width)
generate_memory_file("io_device1_init.mem", num_units_io1, data_width)
