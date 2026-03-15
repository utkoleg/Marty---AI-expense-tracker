# `analyze-receipt`

Supabase Edge Function for Claude-based receipt parsing.

## Secrets

Set these before deploy:

```bash
supabase secrets set ANTHROPIC_API_KEY=your_key_here
supabase secrets set ANTHROPIC_MODEL=claude-haiku-4-5-20251001
supabase secrets set ANTHROPIC_MAX_TOKENS=4000
```

`ANTHROPIC_MODEL` and `ANTHROPIC_MAX_TOKENS` are optional. The function has defaults.

## Deploy

```bash
supabase functions deploy analyze-receipt --no-verify-jwt
```

This repo already disables the platform JWT gate in [supabase/config.toml](/Users/utkoleg/ReceiptlyNative/supabase/config.toml). That is intentional.

Why:
- Supabase's gateway-level JWT check can return `401 Invalid JWT` with newer `publishable` keys before your function code even runs.
- This function performs auth inside `index.ts` by reading the incoming `Authorization` header and calling `supabase.auth.getUser()`.
- That keeps the endpoint restricted to signed-in users without relying on the deprecated gateway behavior.

If you still see `401` and the function log has `execution_id = null`, redeploy again with `--no-verify-jwt`. That means Supabase is still serving an older deployment/config.

## Request body

```json
{
  "images": [
    {
      "base64": "BASE64_IMAGE_DATA",
      "mediaType": "image/jpeg"
    }
  ],
  "timeoutSeconds": 60
}
```

The function also accepts `b64` and `media_type` for easier migration from the current iOS analyzer.

## Response shape

The function returns extracted JSON directly, matching the current `ReceiptGroup` expectations in iOS:

- `{"not_receipt": true}`
- one receipt-group object
- an array of receipt-group objects

## Recommended iOS migration

1. Keep `Supabase Auth` in the app.
2. Replace direct calls to Anthropic in `AnthropicReceiptAnalyzer.swift` with `supabase.functions.invoke("analyze-receipt", ...)`.
3. Reuse the existing local parsing path after decoding the function response.
