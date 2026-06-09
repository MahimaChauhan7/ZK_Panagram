use dep::keccak256;

fn main(guess_hash: Field, answer_double_hash: pub Field, address: pub Field) {
    let addr_pow = address.pow_32(2);

    let guess_hash_decomposed: [u8; 32] = guess_hash.to_be_bytes();

    let guess_double_hash_decomposed: [u8; 32] = keccak256::keccak256(guess_hash_decomposed, 32);

    assert(addr_pow == address.pow_32(2));
    assert(Field::from_be_bytes(guess_double_hash_decomposed) == answer_double_hash);
}


