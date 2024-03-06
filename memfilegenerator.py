import random

def generate_memory_file(filename, num_units):
    with open(filename, 'w') as file:
        for _ in range(num_units):
            value = random.randint(0, 255)  # Generate a random 8-bit value
            file.write(f"{value:02X}\n")  # Write the value in hex format

# Assuming NUM_UNITS_MEMORY is 524288 and NUM_UNITS_IO_DEVICE0 is 16, NUM_UNITS_IO_DEVICE1 is 257
generate_memory_file("memory0_init.mem", 512*1024)
generate_memory_file("memory1_init.mem", 512*1024)
generate_memory_file("io_device0_init.mem", 16)
generate_memory_file("io_device1_init.mem", 512)
