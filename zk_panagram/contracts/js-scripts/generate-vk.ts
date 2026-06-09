import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";

async function main() {
  const { Barretenberg, UltraHonkBackend } =
    (await import("@aztec/bb.js")) as any;

  const circuitPath = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    "../../Circuits/target/zk_panagram.json",
  );
  const circuit = JSON.parse(fs.readFileSync(circuitPath, "utf8"));

  const bb = await Barretenberg.new();
  const honk = new UltraHonkBackend(circuit.bytecode, { threads: 1 });

  try {
    const vk = await honk.getVerificationKey();
    const vkBuf = Buffer.from(vk);
    const outDir = path.resolve(
      path.dirname(fileURLToPath(import.meta.url)),
      "../out",
    );
    if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
    const vkPath = path.join(outDir, "zk_panagram.vk");
    fs.writeFileSync(vkPath, vkBuf);
    console.log("Wrote verification key to", vkPath);

    if (typeof honk.getSolidityVerifier === "function") {
      const sol = await honk.getSolidityVerifier();
      const srcDir = path.resolve(
        path.dirname(fileURLToPath(import.meta.url)),
        "../src",
      );
      if (!fs.existsSync(srcDir)) fs.mkdirSync(srcDir, { recursive: true });
      const verPath = path.join(srcDir, "Verifier.sol");
      fs.writeFileSync(verPath, sol);
      console.log("Wrote Solidity verifier to", verPath);
    } else {
      console.warn("getSolidityVerifier not available on this backend");
    }
  } finally {
    if (honk && honk.destroy) await honk.destroy();
    if (bb && bb.destroy) await bb.destroy();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
