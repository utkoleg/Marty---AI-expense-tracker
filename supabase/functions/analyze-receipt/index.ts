import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const categoryNames = [
  "Groceries",
  "Dining",
  "Fast Food",
  "Coffee",
  "Alcohol",
  "Rent",
  "Housing",
  "Mortgage",
  "Utilities",
  "Internet",
  "Phone",
  "Transport",
  "Gas",
  "Parking",
  "Taxi / Uber",
  "Flights",
  "Hotel",
  "Travel",
  "Healthcare",
  "Pharmacy",
  "Dentist",
  "Gym",
  "Sports",
  "Outdoor",
  "Electronics",
  "Clothing",
  "Shoes",
  "Accessories",
  "Beauty",
  "Skincare",
  "Haircare",
  "Shopping",
  "Home & Garden",
  "Furniture",
  "Cleaning",
  "Pets",
  "Kids",
  "Baby",
  "Education",
  "Books",
  "Streaming",
  "Gaming",
  "Entertainment",
  "Subscriptions",
  "Office",
  "Gifts",
  "Charity",
  "Insurance",
  "Taxes",
  "Other",
] as const;

const prompt = `Is this a receipt/invoice/bill/financial document?
No-> {"not_receipt":true}
Yes-> JSON array where EACH category gets its OWN object. If items span 3 categories, output 3 objects. No markdown:
[{"merchant":"","date":"YYYY-MM-DD","total":0,"currency":"ISO_4217_CODE","category":"","items":[{"name":"","quantity":1,"price":0}],"notes":""}]
Rules: One object per category. Group total=sum of its items. Tax/shipping->add to largest group.
Categories: ${categoryNames.join(", ")}
Use the actual receipt currency. Examples: USD, EUR, KZT, RUB, GBP.
Categorize by item type not store name:
- protein/creatine/BCAAs/supplements->Gym
- workout gear/gym clothes->Gym
- medicine/vitamins/pills/OTC drugs->Pharmacy
- prescriptions/lab tests->Healthcare
- cookware/spatulas/utensils->Home & Garden
- sports equipment/shoes->Sports
- food delivery->Fast Food
- fresh food/produce/pantry->Groceries
- clothing/apparel/shoes->Clothing
- Only use Shopping if item truly doesn't fit any other category
Extract ALL line items. Never collapse multiple categories into one.`;

type IncomingImage = {
  base64?: string;
  b64?: string;
  mediaType?: string;
  media_type?: string;
};

type AnalyzeReceiptRequest = {
  images?: IncomingImage[];
  timeoutSeconds?: number;
};

type AnthropicResponse = {
  content?: Array<{ type?: string; text?: string }>;
  error?: { message?: string; type?: string };
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

async function authenticateRequest(request: Request) {
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return {
      error: jsonResponse({ error: "Missing authorization header." }, 401),
      userId: null,
    };
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseURL || !supabaseAnonKey) {
    return {
      error: jsonResponse({ error: "Supabase auth environment is not configured." }, 500),
      userId: null,
    };
  }

  const supabase = createClient(supabaseURL, supabaseAnonKey, {
    global: {
      headers: {
        Authorization: authorization,
      },
    },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const { data, error } = await supabase.auth.getUser();

  if (error || !data.user) {
    return {
      error: jsonResponse({ error: "Invalid user token." }, 401),
      userId: null,
    };
  }

  return {
    error: null,
    userId: data.user.id,
  };
}

function clamp(value: number, min: number, max: number) {
  return Math.min(Math.max(value, min), max);
}

function parseNumberOrFallback(value: unknown, fallback: number) {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function extractJSON(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    // Fall through to substring extraction.
  }

  const firstBracket = text.indexOf("[");
  const firstBrace = text.indexOf("{");
  const lastBracket = text.lastIndexOf("]");
  const lastBrace = text.lastIndexOf("}");

  const starts = [firstBracket, firstBrace].filter((index) => index >= 0);
  const ends = [lastBracket, lastBrace].filter((index) => index >= 0);

  if (starts.length === 0 || ends.length === 0) {
    throw new Error("No JSON found in Claude response.");
  }

  const start = Math.min(...starts);
  const end = Math.max(...ends);

  if (start > end) {
    throw new Error("Invalid JSON boundaries in Claude response.");
  }

  return JSON.parse(text.slice(start, end + 1));
}

function normalizeImages(images: IncomingImage[] | undefined) {
  if (!Array.isArray(images) || images.length === 0) {
    throw new Error("Request must include at least one image.");
  }

  return images.map((image, index) => {
    const base64 = image.base64?.trim() || image.b64?.trim() || "";
    const mediaType = image.mediaType?.trim() || image.media_type?.trim() || "image/jpeg";

    if (!base64) {
      throw new Error(`Image ${index + 1} is missing base64 data.`);
    }

    return {
      type: "image",
      source: {
        type: "base64",
        media_type: mediaType,
        data: base64,
      },
    };
  });
}

function extractAnthropicText(payload: AnthropicResponse) {
  const text = (payload.content ?? [])
    .filter((block) => block.type === "text" && typeof block.text === "string")
    .map((block) => block.text ?? "")
    .join("");

  if (!text.trim()) {
    throw new Error("Claude response did not contain text content.");
  }

  return text;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const auth = await authenticateRequest(request);
  if (auth.error) {
    return auth.error;
  }

  const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!anthropicKey) {
    return jsonResponse({ error: "Missing ANTHROPIC_API_KEY secret." }, 500);
  }

  let body: AnalyzeReceiptRequest;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  let imageBlocks;
  try {
    imageBlocks = normalizeImages(body.images);
  } catch (error) {
    return jsonResponse({ error: error instanceof Error ? error.message : "Invalid image payload." }, 400);
  }

  const timeoutSeconds = clamp(parseNumberOrFallback(body.timeoutSeconds, 60), 5, 120);
  const model = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-haiku-4-5-20251001";
  const maxTokens = clamp(parseNumberOrFallback(Number(Deno.env.get("ANTHROPIC_MAX_TOKENS")), 4000), 256, 8192);

  const promptText = imageBlocks.length > 1
    ? `These ${imageBlocks.length} images are different pages/parts of the SAME receipt. Treat them as one document and extract all items across all pages.\n\n${prompt}`
    : prompt;

  const controller = new AbortController();
  const timeoutID = setTimeout(() => controller.abort(), timeoutSeconds * 1000);

  try {
    const anthropicResponse = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": anthropicKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model,
        max_tokens: maxTokens,
        messages: [
          {
            role: "user",
            content: [
              ...imageBlocks,
              {
                type: "text",
                text: promptText,
              },
            ],
          },
        ],
      }),
      signal: controller.signal,
    });

    const rawPayload = (await anthropicResponse.json()) as AnthropicResponse;

    if (!anthropicResponse.ok) {
      const message = rawPayload.error?.message ?? `Anthropic returned ${anthropicResponse.status}.`;
      return jsonResponse({ error: message }, 502);
    }

    const text = extractAnthropicText(rawPayload);
    const extractedJSON = extractJSON(text);

    return jsonResponse(extractedJSON);
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      return jsonResponse({ error: "Claude request timed out." }, 504);
    }

    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unexpected analyze-receipt error." },
      500,
    );
  } finally {
    clearTimeout(timeoutID);
  }
});
