import { ethers } from "ethers";
import { execFileSync } from "child_process";
import fs from "fs";
import os from "os";
import path from "path";
import { fileURLToPath } from "url";

const contractsDir = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const circuitsDir = path.resolve(contractsDir, "../Circuits");
const nargoBin =
  process.env.NARGO_BIN ?? path.join(os.homedir(), ".nargo/bin/nargo");
const bbBin = process.env.BB_BIN ?? path.join(os.homedir(), ".bb/bb");

function run(cmd: string, args: string[], cwd: string) {
  execFileSync(cmd, args, {
    cwd,
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env, PATH: process.env.PATH },
  });
}

export default async function generateProof() {
  const [guessHash, answerDoubleHash, address] = process.argv.slice(2);
  const proverToml = [
    `guess_hash = "${guessHash}"`,
    `answer_double_hash = "${answerDoubleHash}"`,
    `address = "${address}"`,
    "",
  ].join("\n");

  fs.writeFileSync(path.join(circuitsDir, "Prover.toml"), proverToml);

  const witnessName = `witness_${process.pid}`;
  const witnessPath = path.join(circuitsDir, "target", `${witnessName}.gz`);
  const proofDir = fs.mkdtempSync(path.join(os.tmpdir(), "zk-panagram-proof-"));

  try {
    run(nargoBin, ["execute", witnessName], circuitsDir);
    run(
      bbBin,
      [
        "prove",
        "-b",
        "target/zk_panagram.json",
        "-w",
        `target/${witnessName}.gz`,
        "-k",
        path.join(contractsDir, "out/vk"),
        "-o",
        proofDir,
        "-t",
        "evm-no-zk",
      ],
      circuitsDir,
    );

    const proof = fs.readFileSync(path.join(proofDir, "proof"));
    const publicInputBytes = fs.readFileSync(
      path.join(proofDir, "public_inputs"),
    );
    const publicInputs: string[] = [];
    for (let i = 0; i < publicInputBytes.length; i += 32) {
      publicInputs.push(
        ethers.hexlify(publicInputBytes.subarray(i, i + 32)),
      );
    }

    return ethers.AbiCoder.defaultAbiCoder().encode(
      ["bytes", "bytes32[]"],
      [proof, publicInputs],
    );
  } finally {
    fs.rmSync(proofDir, { recursive: true, force: true });
    fs.rmSync(witnessPath, { force: true });
  }
}

(async () => {
  generateProof()
    .then((res) => {
      process.stdout.write(res);
      process.exit(0);
    })
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
})();
