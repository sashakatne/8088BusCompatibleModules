import random

mem_address_width = 19
io_address_width = 16
data_width = 8

def generate_memory_file(filename, num_units, data_width):
    with open(filename, 'w') as file:
        for _ in range(num_units):
            value = random.randint(0, 2**data_width - 1)
            file.write(f"{value:02X}\n")  # Write the value in hex format

generate_memory_file("memory0_init.mem", 2**19, 8)
generate_memory_file("memory1_init.mem", 2**19, 8)
generate_memory_file("io_device0_init.mem", 2**16, 8)
generate_memory_file("io_device1_init.mem", 2**16, 8)
