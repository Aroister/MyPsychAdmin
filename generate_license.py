from license_manager import get_machine_id, generate_signature

machine_id = input("Enter machine ID: ").strip()
expiry = input("Enter expiry date (YYYY-MM-DD): ").strip()

signature = generate_signature(machine_id, expiry)
key = f"{machine_id}|{expiry}|{signature}"

print("\nLICENSE KEY:")
print(key)
print("\nGive this string to the user.\n")
