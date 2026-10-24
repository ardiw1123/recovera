// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ESGCertificateRegistry
 * @dev Smart contract sederhana untuk pencatatan dan verifikasi hash sertifikat ESG
 * pada jaringan BOT Chain Testnet.
 */
contract ESGCertificateRegistry {
    address public owner;

    // Mapping dari certificateNo ke certHash (Keccak256 hash dari data sertifikat)
    mapping(string => bytes32) private certificates;

    // Event saat sertifikat baru berhasil disimpan
    event CertificateStored(
        string certificateNo,
        bytes32 certHash,
        uint256 timestamp
    );

    // Modifier akses terbatas khusus owner (relayer backend)
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     * @dev Set owner awal saat deployment contract ke msg.sender (relayer)
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Menyimpan hash sertifikat baru ke blockchain.
     * @param certificateNo Nomor registrasi sertifikat (misal: ESG-20261024-001)
     * @param certHash Hash 32-byte dari data sertifikat
     */
    function storeHash(string calldata certificateNo, bytes32 certHash) external onlyOwner {
        require(bytes(certificateNo).length > 0, "Certificate number cannot be empty");
        require(certHash != bytes32(0), "Certificate hash cannot be zero");
        require(certificates[certificateNo] == bytes32(0), "Certificate already exists");

        certificates[certificateNo] = certHash;

        emit CertificateStored(certificateNo, certHash, block.timestamp);
    }

    /**
     * @dev Mengambil hash sertifikat yang telah tersimpan.
     * @param certificateNo Nomor registrasi sertifikat yang ingin diverifikasi
     * @return bytes32 Hash dari data sertifikat, atau 0x0 jika tidak ditemukan
     */
    function getHash(string calldata certificateNo) external view returns (bytes32) {
        return certificates[certificateNo];
    }

    /**
     * @dev Memindahkan kepemilikan contract ke owner baru (opsional untuk pemeliharaan)
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }
}
