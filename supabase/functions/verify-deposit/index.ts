import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const transferTopic =
  "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef";

type NetworkName =
  | "Polygon"
  | "BNB Smart Chain"
  | "Ethereum (ERC-20)"
  | "Solana"
  | "TRON (TRC-20)";

type EvmNetwork = {
  kind: "evm";
  name: NetworkName;
  rpcUrl: string;
  chainId: string;
  recipient: string;
  token: string;
  decimals: number;
  confirmationsRequired: number;
};

type SolanaNetwork = {
  kind: "solana";
  name: "Solana";
  rpcUrl: string;
  recipient: string;
  token: string;
  decimals: number;
};

type TronNetwork = {
  kind: "tron";
  name: "TRON (TRC-20)";
  rpcUrl: string;
  recipient: string;
  token: string;
  decimals: number;
};

type NetworkConfig = EvmNetwork | SolanaNetwork | TronNetwork;

type VerifiedTransfer = {
  blockNumber: string;
  confirmations: number;
  senderAddress: string | null;
  amountRaw: string;
};

class RequestError extends Error {
  constructor(
    message: string,
    readonly status = 400,
  ) {
    super(message);
  }
}

class RpcError extends Error {
  constructor(message: string) {
    super(message);
  }
}

const networkConfigs: Record<NetworkName, NetworkConfig> = {
  Polygon: {
    kind: "evm",
    name: "Polygon",
    rpcUrl: Deno.env.get("POLYGON_RPC_URL") ??
      "https://polygon-bor-rpc.publicnode.com",
    chainId: "0x89",
    recipient: "",
    token: "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
    decimals: 6,
    confirmationsRequired: 128,
  },
  "BNB Smart Chain": {
    kind: "evm",
    name: "BNB Smart Chain",
    rpcUrl: Deno.env.get("BSC_RPC_URL") ??
      "https://bsc-rpc.publicnode.com",
    chainId: "0x38",
    recipient: "",
    token: "0x55d398326f99059fF775485246999027B3197955",
    decimals: 18,
    confirmationsRequired: 45,
  },
  "Ethereum (ERC-20)": {
    kind: "evm",
    name: "Ethereum (ERC-20)",
    rpcUrl: Deno.env.get("ETHEREUM_RPC_URL") ??
      "https://ethereum-rpc.publicnode.com",
    chainId: "0x1",
    recipient: "",
    token: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    decimals: 6,
    confirmationsRequired: 64,
  },
  Solana: {
    kind: "solana",
    name: "Solana",
    rpcUrl: Deno.env.get("SOLANA_RPC_URL") ??
      "https://api.mainnet-beta.solana.com",
    recipient: "",
    token: "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB",
    decimals: 6,
  },
  "TRON (TRC-20)": {
    kind: "tron",
    name: "TRON (TRC-20)",
    rpcUrl: Deno.env.get("TRON_RPC_URL") ?? "https://api.trongrid.io",
    recipient: "",
    token: "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
    decimals: 6,
  },
};

function respond(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function requiredText(value: unknown, field: string, maxLength: number): string {
  if (typeof value !== "string") {
    throw new RequestError(`${field} is required.`);
  }
  const normalized = value.trim();
  if (!normalized || normalized.length > maxLength) {
    throw new RequestError(`${field} is invalid.`);
  }
  return normalized;
}

function validateTransactionHash(network: NetworkName, value: string): string {
  const valid = network === "Polygon" ||
      network === "BNB Smart Chain" ||
      network === "Ethereum (ERC-20)"
    ? /^0x[a-fA-F0-9]{64}$/.test(value)
    : network === "Solana"
    ? /^[1-9A-HJ-NP-Za-km-z]{80,100}$/.test(value)
    : /^[a-fA-F0-9]{64}$/.test(value);

  if (!valid) {
    throw new RequestError("The transaction hash format is invalid for this network.");
  }
  return network === "Solana" ? value : value.toLowerCase();
}

async function postJson(
  url: string,
  body: unknown,
  headers: Record<string, string> = {},
): Promise<unknown> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 12_000);
  try {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...headers },
      body: JSON.stringify(body),
      signal: controller.signal,
      redirect: "error",
    });
    if (!response.ok) {
      throw new RpcError(`Blockchain node returned HTTP ${response.status}.`);
    }
    return await response.json();
  } catch (error) {
    if (error instanceof RpcError) throw error;
    throw new RpcError("Could not read a response from the blockchain node.");
  } finally {
    clearTimeout(timeout);
  }
}

async function evmRpc(
  config: EvmNetwork,
  method: string,
  params: unknown[],
): Promise<unknown> {
  const response = await postJson(config.rpcUrl, {
    jsonrpc: "2.0",
    id: 1,
    method,
    params,
  });
  if (
    !isRecord(response) ||
    response.error !== undefined ||
    response.result === undefined
  ) {
    throw new RpcError(`Blockchain node could not complete ${method}.`);
  }
  return response.result;
}

function parseHexInteger(value: unknown, field: string): bigint {
  if (typeof value !== "string" || !/^0x[0-9a-fA-F]+$/.test(value)) {
    throw new RpcError(`Blockchain node returned an invalid ${field}.`);
  }
  return BigInt(value);
}

async function verifyEvmTransfer(
  config: EvmNetwork,
  transactionHash: string,
): Promise<VerifiedTransfer | null> {
  const chainIdValue = await evmRpc(config, "eth_chainId", []);
  if (typeof chainIdValue !== "string") {
    throw new RpcError("Blockchain node returned an invalid chain ID.");
  }
  const chainId = chainIdValue;
  if (chainId.toLowerCase() !== config.chainId) {
    throw new RpcError("Blockchain node is connected to the wrong network.");
  }
  const decimalsValue = await evmRpc(config, "eth_call", [
    { to: config.token, data: "0x313ce567" },
    "latest",
  ]);
  if (
    typeof decimalsValue !== "string" ||
    !/^0x[0-9a-fA-F]+$/.test(decimalsValue) ||
    Number(BigInt(decimalsValue)) !== config.decimals
  ) {
    throw new RpcError("The configured USDT contract has unexpected decimals.");
  }

  const receipt = await evmRpc(
    config,
    "eth_getTransactionReceipt",
    [transactionHash],
  );
  if (receipt === null) return null;
  if (!isRecord(receipt) || receipt.status !== "0x1") {
    throw new RequestError("The on-chain transaction failed.");
  }

  const blockNumber = parseHexInteger(receipt.blockNumber, "transaction block");
  const latestBlock = parseHexInteger(
    await evmRpc(config, "eth_blockNumber", []),
    "latest block",
  );
  const confirmationsBigInt = latestBlock - blockNumber + 1n;
  const confirmations = Number(
    confirmationsBigInt > 0n ? confirmationsBigInt : 0n,
  );
  if (confirmations < config.confirmationsRequired) {
    return null;
  }

  if (!Array.isArray(receipt.logs)) {
    throw new RpcError("Blockchain node returned an invalid transaction receipt.");
  }

  const recipient = config.recipient.slice(2).toLowerCase();
  const token = config.token.toLowerCase();
  let amountRaw = 0n;
  let senderAddress: string | null = null;
  for (const log of receipt.logs) {
    if (!isRecord(log) || typeof log.address !== "string") continue;
    if (log.address.toLowerCase() !== token || !Array.isArray(log.topics)) {
      continue;
    }
    const topics = log.topics;
    if (
      typeof topics[0] !== "string" ||
      topics[0].toLowerCase() !== transferTopic ||
      typeof topics[1] !== "string" ||
      typeof topics[2] !== "string" ||
      topics[2].slice(-40).toLowerCase() !== recipient ||
      typeof log.data !== "string" ||
      !/^0x[0-9a-fA-F]+$/.test(log.data)
    ) {
      continue;
    }
    amountRaw += BigInt(log.data);
    if (senderAddress === null) {
      senderAddress = `0x${topics[1].slice(-40)}`;
    }
  }

  if (amountRaw <= 0n) {
    throw new RequestError(
      "No USDT transfer to the Tamleek address was found in this transaction.",
    );
  }

  return {
    blockNumber: blockNumber.toString(),
    confirmations,
    senderAddress,
    amountRaw: amountRaw.toString(),
  };
}

type SolanaTokenBalance = {
  accountIndex: number;
  mint: string;
  owner?: string;
  uiTokenAmount?: {
    amount?: string;
    decimals?: number;
  };
};

function solanaTokenBalances(
  values: unknown,
  config: SolanaNetwork,
): Map<number, bigint> {
  if (!Array.isArray(values)) {
    throw new RpcError("Solana node returned invalid token balances.");
  }
  const balances = new Map<number, bigint>();
  for (const value of values) {
    if (!isRecord(value)) continue;
    const balance = value as SolanaTokenBalance;
    if (balance.mint !== config.token || balance.owner !== config.recipient) {
      continue;
    }
    const raw = balance.uiTokenAmount?.amount;
    if (
      typeof balance.accountIndex !== "number" ||
      typeof raw !== "string" ||
      balance.uiTokenAmount?.decimals !== config.decimals
    ) {
      throw new RpcError("Solana node returned an invalid USDT token balance.");
    }
    balances.set(balance.accountIndex, BigInt(raw));
  }
  return balances;
}

async function solanaRpc(
  config: SolanaNetwork,
  method: string,
  params: unknown[],
): Promise<unknown> {
  const response = await postJson(config.rpcUrl, {
    jsonrpc: "2.0",
    id: 1,
    method,
    params,
  });
  if (
    !isRecord(response) ||
    response.error !== undefined ||
    response.result === undefined
  ) {
    throw new RpcError(`Solana node could not complete ${method}.`);
  }
  return response.result;
}

async function verifySolanaTransfer(
  config: SolanaNetwork,
  transactionHash: string,
): Promise<VerifiedTransfer | null> {
  const result = await solanaRpc(config, "getTransaction", [
    transactionHash,
    { commitment: "finalized", maxSupportedTransactionVersion: 0 },
  ]);
  if (result === null) return null;
  if (!isRecord(result) || !isRecord(result.meta) || result.meta.err !== null) {
    throw new RequestError("The on-chain transaction failed or is invalid.");
  }

  const slot = result.slot;
  if (typeof slot !== "number" || !Number.isSafeInteger(slot)) {
    throw new RpcError("Solana node returned an invalid transaction slot.");
  }
  const finalizedSlot = await solanaRpc(config, "getSlot", [
    { commitment: "finalized" },
  ]);
  if (
    typeof finalizedSlot !== "number" ||
    !Number.isSafeInteger(finalizedSlot)
  ) {
    throw new RpcError("Solana node returned an invalid finalized slot.");
  }
  if (slot > finalizedSlot) return null;

  const before = solanaTokenBalances(result.meta.preTokenBalances, config);
  const after = solanaTokenBalances(result.meta.postTokenBalances, config);
  const accountIndexes = new Set([...before.keys(), ...after.keys()]);
  let amountRaw = 0n;
  for (const index of accountIndexes) {
    amountRaw += (after.get(index) ?? 0n) - (before.get(index) ?? 0n);
  }
  if (amountRaw <= 0n) {
    throw new RequestError(
      "No finalized USDT transfer to the Tamleek address was found.",
    );
  }

  return {
    blockNumber: slot.toString(),
    confirmations: 1,
    senderAddress: null,
    amountRaw: amountRaw.toString(),
  };
}

const base58Alphabet =
  "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

async function tronAddressHex(address: string): Promise<string> {
  let value = 0n;
  for (const character of address) {
    const digit = base58Alphabet.indexOf(character);
    if (digit < 0) throw new RpcError("Invalid configured TRON address.");
    value = value * 58n + BigInt(digit);
  }

  const decoded: number[] = [];
  while (value > 0n) {
    decoded.unshift(Number(value & 0xffn));
    value >>= 8n;
  }
  for (const character of address) {
    if (character !== "1") break;
    decoded.unshift(0);
  }
  if (decoded.length !== 25) {
    throw new RpcError("Invalid configured TRON address.");
  }

  const payload = new Uint8Array(decoded.slice(0, 21));
  const firstHash = await crypto.subtle.digest("SHA-256", payload);
  const checksum = new Uint8Array(
    await crypto.subtle.digest("SHA-256", firstHash),
  ).slice(0, 4);
  if (
    checksum.some((byte, index) => byte !== decoded[21 + index]) ||
    payload[0] !== 0x41
  ) {
    throw new RpcError("Invalid configured TRON address checksum.");
  }
  return Array.from(payload, (byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function tronLogAddressHex(address: string): string {
  const hex = address.toLowerCase().replace(/^0x/, "");
  if (hex.length === 42 && hex.startsWith("41")) return hex.slice(2);
  return hex.length === 40 ? hex : "";
}

async function verifyTronTransfer(
  config: TronNetwork,
  transactionHash: string,
): Promise<VerifiedTransfer | null> {
  const [infoValue, tokenHex, recipientHex] = await Promise.all([
    postJson(`${config.rpcUrl}/walletsolidity/gettransactioninfobyid`, {
      value: transactionHash,
    }),
    tronAddressHex(config.token),
    tronAddressHex(config.recipient),
  ]);
  if (!isRecord(infoValue) || !infoValue.id) return null;
  if (typeof infoValue.id !== "string" ||
      infoValue.id.toLowerCase() !== transactionHash) {
    throw new RpcError("TRON node returned a different transaction.");
  }
  if (!isRecord(infoValue.receipt) || infoValue.receipt.result !== "SUCCESS") {
    throw new RequestError("The on-chain transaction failed.");
  }
  if (!Array.isArray(infoValue.log)) {
    throw new RpcError("TRON node returned invalid transaction logs.");
  }

  const recipient = recipientHex.slice(-40);
  const token = tokenHex.slice(-40).toLowerCase();
  let amountRaw = 0n;
  let senderAddress: string | null = null;
  for (const log of infoValue.log) {
    if (!isRecord(log) || typeof log.address !== "string") continue;
    if (
      tronLogAddressHex(log.address) !== token ||
      !Array.isArray(log.topics)
    ) {
      continue;
    }
    const topics = log.topics;
    const topic0 = typeof topics[0] === "string"
      ? topics[0].toLowerCase().replace(/^0x/, "")
      : "";
    const data = typeof log.data === "string"
      ? log.data.replace(/^0x/i, "")
      : "";
    if (
      topic0 !== transferTopic.slice(2) ||
      typeof topics[1] !== "string" ||
      typeof topics[2] !== "string" ||
      topics[2].slice(-40).toLowerCase() !== recipient ||
      !/^[0-9a-fA-F]+$/.test(data)
    ) {
      continue;
    }
    amountRaw += BigInt(`0x${data}`);
    if (senderAddress === null) {
      senderAddress = `0x${topics[1].slice(-40)}`;
    }
  }
  if (amountRaw <= 0n) {
    throw new RequestError(
      "No solidified USDT transfer to the Tamleek address was found.",
    );
  }

  const blockNumber = infoValue.blockNumber;
  if (
    (typeof blockNumber !== "number" && typeof blockNumber !== "string") ||
    !/^[0-9]+$/.test(String(blockNumber))
  ) {
    throw new RpcError("TRON node returned an invalid solidified block.");
  }

  return {
    blockNumber: String(blockNumber),
    confirmations: 1,
    senderAddress,
    amountRaw: amountRaw.toString(),
  };
}

async function verifyTransfer(
  config: NetworkConfig,
  transactionHash: string,
): Promise<VerifiedTransfer | null> {
  switch (config.kind) {
    case "evm":
      return await verifyEvmTransfer(config, transactionHash);
    case "solana":
      return await verifySolanaTransfer(config, transactionHash);
    case "tron":
      return await verifyTronTransfer(config, transactionHash);
  }
}

function formatTokenAmount(amountRaw: string, decimals: number): string {
  const amount = BigInt(amountRaw);
  const scale = 10n ** BigInt(decimals);
  const whole = amount / scale;
  const fraction = (amount % scale).toString().padStart(decimals, "0")
    .replace(/0+$/, "");
  return fraction ? `${whole}.${fraction}` : whole.toString();
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return respond({ error: "Method not allowed." }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization) {
    return respond({ error: "Sign in before verifying a deposit." }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error("Deposit verification service secrets are not configured.");
    return respond({ error: "Deposit verification service is not configured." }, 503);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return respond({ error: "The authentication session is invalid." }, 401);
  }

  try {
    const { data: verificationSetting, error: settingError } = await adminClient
      .from("deposit_verification_settings")
      .select("auto_enabled")
      .eq("id", "global")
      .maybeSingle();
    if (settingError) throw settingError;
    if (verificationSetting?.auto_enabled !== true) {
      return respond({ status: "manual_required" });
    }

    const rawBody = await request.text();
    if (rawBody.length > 2048) {
      throw new RequestError("The request body is too large.", 413);
    }
    let body: unknown;
    try {
      body = JSON.parse(rawBody);
    } catch {
      throw new RequestError("The request body is invalid.");
    }
    if (!isRecord(body)) {
      throw new RequestError("The request body is invalid.");
    }

    const network = requiredText(body.network, "network", 40) as NetworkName;
    const networkConfig = networkConfigs[network];
    if (!networkConfig) {
      throw new RequestError("The selected network is not supported.");
    }
    const user = userData.user;
    const transactionHash = validateTransactionHash(
      network,
      requiredText(body.transactionHash, "transactionHash", 100),
    );

    const { data: manualRequest, error: manualRequestError } = await adminClient
      .from("deposit_requests")
      .select("id, user_id, status, amount_usdt, review_note")
      .eq("network", network)
      .eq("transaction_hash", transactionHash)
      .maybeSingle();
    if (manualRequestError) throw manualRequestError;
    if (manualRequest) {
      if (manualRequest.user_id !== user.id) {
        throw new RequestError(
          "This transaction has already been submitted.",
          409,
        );
      }
      return respond({
        status: "manual_review",
        depositRequest: manualRequest,
      });
    }

    const { data: existing, error: existingError } = await adminClient
      .from("onchain_deposit_verifications")
      .select(
        "id, user_id, network, transaction_hash, token_address, sender_address, recipient_address, amount_raw, token_decimals, block_number, confirmations, status, verified_at, credited_at",
      )
      .eq("network", network)
      .eq("transaction_hash", transactionHash)
      .maybeSingle();
    if (existingError) throw existingError;
    if (existing) {
      if (existing.user_id !== user.id) {
        throw new RequestError(
          "This transaction has already been credited.",
          409,
        );
      }
      return respond({ status: existing.status, deposit: existing });
    }

    const { data: addressRecord, error: addressError } = await adminClient
      .from("user_deposit_addresses")
      .select("recipient_address")
      .eq("user_id", user.id)
      .eq("network", network)
      .maybeSingle();
    if (addressError) throw addressError;
    if (!addressRecord) {
      throw new RequestError(
        "A deposit address has not been assigned to this account.",
        409,
      );
    }
    const config: NetworkConfig = {
      ...networkConfig,
      recipient: addressRecord.recipient_address,
    };

    const verified = await verifyTransfer(config, transactionHash);
    if (!verified) {
      return respond({
        status: "confirming",
        message:
          "The transaction is not yet available with the required finality.",
      });
    }

    const amountUsdt = formatTokenAmount(
      verified.amountRaw,
      config.decimals,
    );
    const submission = {
      user_id: user.id,
      client_request_id: crypto.randomUUID(),
      network,
      transaction_hash: transactionHash,
      token_address: config.token,
      sender_address: verified.senderAddress,
      recipient_address: config.recipient,
      amount_usdt: amountUsdt,
      block_number: verified.blockNumber,
      confirmations: verified.confirmations,
      verification_source: "automatic",
      verified_at: new Date().toISOString(),
      status: "credited",
    };
    const { data: deposit, error: insertError } = await adminClient
      .from("deposit_requests")
      .insert(submission)
      .select(
        "id, user_id, network, transaction_hash, amount_usdt, token_address, sender_address, recipient_address, block_number, confirmations, verification_source, status, verified_at, created_at",
      )
      .single();
    if (insertError?.code === "23505") {
      const { data: claimed, error: claimError } = await adminClient
        .from("deposit_requests")
        .select("id, user_id, status, amount_usdt, review_note")
        .eq("network", network)
        .eq("transaction_hash", transactionHash)
        .maybeSingle();
      if (claimError) throw claimError;
      if (claimed?.user_id !== user.id) {
        throw new RequestError(
          "This transaction has already been credited.",
          409,
        );
      }
      return respond({ status: "manual_review", depositRequest: claimed });
    }
    if (insertError) throw insertError;

    return respond({
      status: "credited",
      deposit: {
        id: deposit.id,
        network: deposit.network,
        transaction_hash: deposit.transaction_hash,
        amount_raw: verified.amountRaw,
        amount_usdt: amountUsdt,
        token_decimals: config.decimals,
        status: deposit.status,
        created_at: deposit.created_at,
      },
    });
  } catch (error) {
    console.error("On-chain deposit verification failed.", error);
    if (error instanceof RequestError) {
      return respond({ error: error.message }, error.status);
    }
    if (error instanceof RpcError) {
      return respond({
        error: "A direct blockchain node could not verify the transaction.",
      }, 503);
    }
    return respond({ error: "Deposit verification could not be completed." }, 500);
  }
});
