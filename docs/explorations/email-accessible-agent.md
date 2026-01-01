# Email-Accessible Agent

Exploration of adding an agent that can be communicated with over email.

## Overview

An email-accessible agent would allow users to interact with the system via email, making it accessible to users who prefer email over GitHub issues/PRs or other interfaces.

## Architecture Options

### Option 1: Polling-Based (Simplest)

```
[Email Provider] <- (IMAP) <- [Poller Service] -> [GitHub Workflow Trigger]
```

A separate service polls an email inbox periodically, parses new messages, and triggers agent runs via GitHub's `workflow_dispatch` API.

**Pros:**
- Simple to implement
- No inbound webhook infrastructure needed
- Works with any email provider (Gmail, custom SMTP, etc.)

**Cons:**
- Latency (depends on poll interval)
- Requires always-running service
- IMAP credential management

### Option 2: Webhook-Based

```
[Email Provider] -> (webhook) -> [Handler Service] -> [GitHub Workflow Trigger]
```

Email provider sends webhook on new message. Handler parses and triggers workflow.

**Pros:**
- Real-time response
- Event-driven (no polling)

**Cons:**
- Requires email provider with webhook support (SendGrid, Mailgun, etc.)
- Needs publicly accessible endpoint

### Option 3: GitHub Actions Email Trigger (Hypothetical)

If GitHub adds email-based workflow triggers, this would be native. Currently not available.

## Email Provider Options

| Provider | Inbound Webhooks | IMAP Access | Cost | Notes |
|----------|------------------|-------------|------|-------|
| Gmail API | No | Yes (OAuth) | Free | Complex OAuth setup |
| SendGrid | Yes | No | Free tier | Requires domain verification |
| Mailgun | Yes | No | Free tier | 5,000 messages/month |
| Postmark | Yes | No | $10/month | Enterprise focused |
| Custom SMTP | No | Yes | Varies | Full control |

## Security Considerations

### Sender Verification
- **SPF/DKIM/DMARC**: Verify sender domain authenticity
- **Allowlist**: Only process emails from approved senders
- **Shared secret**: Include a token in subject/body for validation
- **PGP/S-MIME**: Cryptographic signature verification (complex)

### Rate Limiting
- Limit messages per sender per time period
- Prevent abuse and resource exhaustion

### Content Sanitization
- Strip HTML, attachments by default
- Parse only plain text or specific formats
- Size limits on message body

## Proposed Architecture

For shimmer, recommend starting with **Option 1 (Polling)** using Gmail API:

```
┌─────────────────────────────────────────────────────────┐
│                    GitHub Actions                        │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐│
│  │ email-agent.yml (runs hourly)                        ││
│  │ 1. Authenticate with Gmail API via OAuth             ││
│  │ 2. Fetch unread messages with label "shimmer"        ││
│  │ 3. For each message:                                 ││
│  │    - Verify sender is in allowlist                   ││
│  │    - Parse message body as task                      ││
│  │    - Run agent with message as prompt                ││
│  │    - Reply with results                              ││
│  │    - Mark message as read                            ││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

This approach:
- Runs entirely in GitHub Actions (no separate infrastructure)
- Uses Gmail's labeling to filter relevant messages
- Provides response by replying to the original email
- Can start simple and evolve

## Implementation Steps

### Phase 1: Basic Email Reading
1. Set up Gmail API credentials (service account or OAuth)
2. Create GitHub Action that reads emails labeled "shimmer"
3. Parse email body as agent prompt
4. Trigger existing agent workflow

### Phase 2: Response Handling
1. Capture agent output
2. Format as email response
3. Send reply via Gmail API

### Phase 3: Thread Support
1. Track conversation threads
2. Include previous context in prompts
3. Support follow-up questions

### Phase 4: Attachments
1. Handle code file attachments
2. Parse and include in context
3. Attach output files to replies

## Secrets Required

- `GMAIL_CLIENT_ID` / `GMAIL_CLIENT_SECRET` (OAuth)
- Or `GMAIL_SERVICE_ACCOUNT_KEY` (service account)
- `EMAIL_ALLOWLIST` (comma-separated sender addresses)

## Open Questions

1. **Dedicated email or shared?** Should each agent have its own email, or one shared inbox with routing?

2. **Response format**: Plain text? Markdown? HTML?

3. **Error handling**: How to communicate failures? Silent? Error email?

4. **Queueing**: What if multiple emails arrive between polls? Process all? FIFO?

5. **Identity**: How does the email agent identify itself in replies?

## Prior Art

- [Claude for Email](https://www.anthropic.com/index/introducing-claude-for-email) - Anthropic's consumer product
- [Zapier Email Parser](https://parser.zapier.com/) - Extract data from emails
- [n8n Email Nodes](https://docs.n8n.io/integrations/builtin/trigger-nodes/n8n-nodes-base.emailimap/) - Workflow automation with email

## Conclusion

An email-accessible agent is feasible within the current shimmer architecture. The polling-based approach using Gmail API can be implemented entirely in GitHub Actions, requiring no additional infrastructure. Start with basic message reading and gradually add reply, thread, and attachment support.

---

Related: #57
