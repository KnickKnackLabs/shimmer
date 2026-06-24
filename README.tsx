/** @jsxImportSource jsx-md */

import { existsSync, readFileSync, readdirSync, statSync } from "fs";
import { join, resolve } from "path";

import {
  Badge,
  Badges,
  Bold,
  Cell,
  Center,
  Code,
  CodeBlock,
  Details,
  Heading,
  HR,
  Item,
  LineBreak,
  Link,
  List,
  Paragraph,
  Raw,
  Section,
  Sub,
  Table,
  TableHead,
  TableRow,
} from "readme";

const PROJECT = {
  name: "shimmer",
  oneLine: "Infrastructure for waking agents in the right body.",
  tagline: "Identity, dispatch, generated CI, and session plumbing for agent homes.",
  license: "MIT",
};

const REPO_DIR = resolve(import.meta.dirname);
const TASK_DIR = join(REPO_DIR, ".mise/tasks");
const TEST_DIR = join(REPO_DIR, "test");
const TEMPLATE_DIR = join(REPO_DIR, ".github/templates");
const WORKFLOW_DIR = join(REPO_DIR, ".github/workflows");

type TaskInfo = {
  name: string;
  description: string;
  path: string;
};

function read(path: string): string {
  return readFileSync(path, "utf8");
}

function walkFiles(dir: string, predicate: (path: string) => boolean): string[] {
  if (!existsSync(dir)) return [];

  const files: string[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...walkFiles(full, predicate));
    } else if (predicate(full)) {
      files.push(full);
    }
  }
  return files;
}

function discoverTasks(dir = TASK_DIR, prefix = ""): TaskInfo[] {
  if (!existsSync(dir)) return [];

  const tasks: TaskInfo[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith(".")) continue;

    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      const nextPrefix = prefix ? `${prefix}:${entry.name}` : entry.name;
      tasks.push(...discoverTasks(full, nextPrefix));
      continue;
    }

    if ((statSync(full).mode & 0o111) === 0) continue;
    if (entry.name.startsWith("_") && entry.name !== "_default") continue;

    const text = read(full);
    if (/^(#|\/\/)MISE\s+hide=true$/m.test(text)) continue;

    const name = entry.name === "_default" ? prefix : prefix ? `${prefix}:${entry.name}` : entry.name;
    if (!name) continue;

    const description =
      text.match(/^#MISE description="(.+)"$/m)?.[1] ??
      text.match(/^\/\/MISE description="(.+)"$/m)?.[1] ??
      "";

    tasks.push({ name, description, path: full });
  }

  return tasks.sort((left, right) => left.name.localeCompare(right.name));
}

function countBatsTests(): number {
  return (
    walkFiles(TEST_DIR, (path) => path.endsWith(".bats"))
      .map(read)
      .join("\n")
      .match(/@test\s+"/g)?.length ?? 0
  );
}

function configuredLints(): string[] {
  const text = read(join(REPO_DIR, "mise.toml"));
  const start = text.indexOf("[_.codebase]");
  if (start === -1) return [];

  const lines = text.slice(start).split("\n");
  const block: string[] = [];
  for (const [index, line] of lines.entries()) {
    if (index > 0 && line.startsWith("[")) break;
    block.push(line);
  }

  const list = block.join("\n").match(/lint\s*=\s*\[([\s\S]*?)\]/)?.[1] ?? "";
  return [...list.matchAll(/"([^"]+)"/g)].map((match) => match[1]);
}

function toolVersion(name: string): string {
  const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = read(join(REPO_DIR, "mise.toml")).match(new RegExp(`"?${escaped}"?\\s*=\\s*"([^"]+)"`));
  return match?.[1] ?? "declared";
}

function fileCount(dir: string, suffix: string): number {
  return walkFiles(dir, (path) => path.endsWith(suffix)).length;
}

const tasks = discoverTasks();
const testCount = countBatsTests();
const lints = configuredLints();
const workflowCount = fileCount(WORKFLOW_DIR, ".yml") + fileCount(WORKFLOW_DIR, ".yaml");
const templateCount = fileCount(TEMPLATE_DIR, ".yml") + fileCount(TEMPLATE_DIR, ".py");

// Manual local-pulse snapshot.
//
// When an agent is working live with Or and wants to refresh this bit of the
// README, do it intentionally instead of making README generation depend on
// machine-local session state. Tracked helper task: shimmer#794.
//
// Current manual refresh shape from a repo/home that declares shiv:sessions:
//
//   mise exec -- sessions query --limit 10000 \
//     --sql 'select count(*) as recorded_sessions from sessions' \
//     --format json
//   mise exec -- sessions ps --json | jq length
//
// Branch tips currently require SQL over fork notices because sessions query
// does not yet expose structured session edges. See shimmer#794 for the planned
// `shimmer readme sessions-pulse` helper. Do not replace this with build-time
// command execution: CI and outside contributors should be able to regenerate
// README.md without having Or-machine session history.
const LOCAL_SESSION_SNAPSHOT = {
  recorded: 659,
  branchTips: 657,
  live: 0,
  captured: "2026-06-23",
  source: "Quick on Or's machine",
};

const groupDescriptions: Record<string, string> = {
  agent: "start, dispatch, list, and provision agents",
  ci: "trigger, wait, watch, and inspect workflow runs",
  workflows: "generate agent workflow files from manifests and rosters",
  github: "profile, org, repo, and token chores",
  gpg: "agent signing key setup and checks",
  matrix: "Matrix login, room, and send helpers",
  metrics: "activity, usage, and digest reporting",
  pm: "GitHub project and issue triage helpers",
  pr: "small pull-request helpers",
  telemetry: "local event emission and inspection",
  web: "fetch and search helpers",
};

const groupedTasks = Object.entries(
  tasks.reduce<Record<string, TaskInfo[]>>((groups, task) => {
    const group = task.name.includes(":") ? task.name.split(":")[0] : task.name;
    groups[group] ??= [];
    groups[group].push(task);
    return groups;
  }, {}),
).sort(([left], [right]) => left.localeCompare(right));

const featuredGroups = groupedTasks.filter(([group]) => groupDescriptions[group]);

const spine = [
  "human / issue / schedule",
  "        │",
  "        ▼",
  "  shimmer agent:dispatch",
  "        │  workflow_dispatch",
  "        ▼",
  " .github/workflows/<agent>.yml",
  "        │  calls",
  "        ▼",
  " .github/workflows/agent-run.yml",
  "        │  checkout home + prepare + restore auth",
  "        ▼",
  "      sessions wake",
  "        │",
  "        ▼",
  "   agent home repo",
].join("\n");

const localIdentityFlow = [
  "# Become Quick for local work; exports git identity, token, home path, and signing key config.",
  "eval \"$(shimmer as quick)\"",
  "shimmer whoami",
  "",
  "# Start an interactive session from the current repo/cwd.",
  "shimmer agent --model openai-codex/gpt-5.5 \"Inspect the failing workflow.\"",
].join("\n");

const dispatchFlow = [
  "cat > /tmp/review.md <<'MSG'",
  "Please review ricon-family/nvr#48. Focus on privacy boundaries and no-tools guarantees.",
  "MSG",
  "",
  "shimmer agent:dispatch brownie \\",
  "  --repo owner/agent-workflows \\",
  "  --model openai-codex/gpt-5.5 \\",
  "  --message-file /tmp/review.md",
].join("\n");

const workflowFlow = [
  "# In a repo that owns generated agent workflows:",
  "shimmer workflows:generate",
  "shimmer workflows:generate --check",
  "git diff -- .github/workflows/",
].join("\n");

const readme = (
  <>
    <Center>
      <Raw>{`<p><img src="assets/logo.svg" alt="shimmer" width="200" height="100" /></p>\n\n`}</Raw>

      <Heading level={1}>{PROJECT.name}</Heading>

      <Paragraph>
        <Bold>{PROJECT.oneLine}</Bold>
      </Paragraph>

      <Paragraph>{PROJECT.tagline}</Paragraph>

      <Raw>{`<p dir="rtl"><em>إلى ريموند — العمل شرف</em></p>\n\n`}</Raw>

      <Badges>
        <Badge label="tasks" value={`${tasks.length}`} color="4EAA25" logo="gnubash" logoColor="white" />
        <Badge label="tests" value={`${testCount}`} color="brightgreen" href="test/" />
        <Badge label="lints" value={`${lints.length}`} color="blue" />
        <Badge label="workflow templates" value={`${templateCount}`} color="8b5cf6" />
        <Badge label="sessions" value={`${LOCAL_SESSION_SNAPSHOT.recorded}`} color="64748b" href="https://github.com/KnickKnackLabs/shimmer/issues/794" />
        <Badge label="tips" value={`${LOCAL_SESSION_SNAPSHOT.branchTips}`} color="64748b" href="https://github.com/KnickKnackLabs/shimmer/issues/794" />
        <Badge label="README" value="TSX" color="f472b6" />
        <Badge label="License" value={PROJECT.license} color="blue" href="LICENSE" />
      </Badges>
    </Center>

    <LineBreak />

    <Section title="What this is">
      <Paragraph>
        <Code>shimmer</Code>
        {" is the switchboard for local and hosted agent work. It knows how to become an agent locally, how to dispatch an agent workflow remotely, and how generated GitHub Actions should prepare the agent's home before a session starts."}
      </Paragraph>

      <Paragraph>
        {"The important boundary is this: work can be about any repository, but the agent still wakes in its home with its own identity, signing key, secrets, notes, and session history. Shimmer keeps that boundary explicit."}
      </Paragraph>
    </Section>

    <Section title="The spine">
      <CodeBlock>{spine}</CodeBlock>

      <Paragraph>
        {"The caller may be a human, a schedule, a mention wake, or another agent. The execution body is still the same: a generated workflow prepares the home repo, restores auth, starts a tracked session, and backs it up when possible."}
      </Paragraph>
    </Section>

    <Section title="Quick start">
      <CodeBlock lang="bash">{`git clone https://github.com/KnickKnackLabs/shimmer.git ~/shimmer
cd ~/shimmer
mise trust
mise install
mise run doctor

# Optional shell integration: exposes the shimmer command from anywhere.
eval "$(mise -C ~/shimmer run -q shell)"
shimmer whoami`}</CodeBlock>
    </Section>

    <Section title="Three workflows worth remembering">
      <Heading level={3}>Local identity</Heading>
      <Paragraph>
        {"Use "}
        <Code>shimmer as</Code>
        {" when a local shell needs the same identity and signing posture as a hosted agent run."}
      </Paragraph>
      <CodeBlock lang="bash">{localIdentityFlow}</CodeBlock>

      <Heading level={3}>Hosted dispatch</Heading>
      <Paragraph>
        {"Dispatch through the repo that owns the target agent workflow, and put the actual target PR or issue in the packet. Use a message file for anything longer than a scalar."}
      </Paragraph>
      <CodeBlock lang="bash">{dispatchFlow}</CodeBlock>

      <Heading level={3}>Generated workflows</Heading>
      <Paragraph>
        {"Agent workflows are generated into the repos that own them. Edit templates and the generator here; regenerate downstream workflow repos intentionally."}
      </Paragraph>
      <CodeBlock lang="bash">{workflowFlow}</CodeBlock>
    </Section>

    <Section title="What shimmer owns">
      <Table>
        <TableHead>
          <Cell>Surface</Cell>
          <Cell>Contract</Cell>
        </TableHead>
        <TableRow>
          <Cell><Code>shimmer as &lt;agent&gt;</Code></Cell>
          <Cell>{"Exports local identity, token, home path, B2 settings, and command-scope git signing config."}</Cell>
        </TableRow>
        <TableRow>
          <Cell><Code>shimmer agent</Code></Cell>
          <Cell>{"Starts interactive or headless sessions while scrubbing task-scoped mise/caller environment before handing control to pi/sessions."}</Cell>
        </TableRow>
        <TableRow>
          <Cell><Code>agent:dispatch</Code></Cell>
          <Cell>{"Finds the right home repo, validates provider-qualified models, preserves file-backed messages, and returns the workflow run id."}</Cell>
        </TableRow>
        <TableRow>
          <Cell><Code>workflows:generate</Code></Cell>
          <Cell>{"Turns agent rosters and workflows.yaml manifests into reusable runner workflows, per-agent entrypoints, schedules, and mention wakes."}</Cell>
        </TableRow>
        <TableRow>
          <Cell><Code>sessions:backup</Code></Cell>
          <Cell>{"Exports local session bundles and uploads snapshots/latest pointers when blob credentials are configured."}</Cell>
        </TableRow>
      </Table>
    </Section>

    <Section title="Task map">
      <Paragraph>
        {"The full command reference belongs to "}
        <Code>shimmer tasks</Code>
        {" and individual "}
        <Code>--help</Code>
        {" output. This map is generated from "}
        <Code>.mise/tasks/</Code>
        {" so it stays honest without becoming a manual."}
      </Paragraph>

      <Table>
        <TableHead>
          <Cell>Group</Cell>
          <Cell>Tasks</Cell>
          <Cell>Job</Cell>
        </TableHead>
        {featuredGroups.map(([group, groupTasks]) => (
          <TableRow>
            <Cell><Code>{group}</Code></Cell>
            <Cell>{`${groupTasks.length}`}</Cell>
            <Cell>{groupDescriptions[group]}</Cell>
          </TableRow>
        ))}
      </Table>

      <Paragraph>
        {"Total public tasks discovered: "}
        <Bold>{`${tasks.length}`}</Bold>
        {". Top-level workflows checked by CI: "}
        <Bold>{`${workflowCount}`}</Bold>
        {"."}
      </Paragraph>
    </Section>

    <Section title="Generated agent CI">
      <Paragraph>
        {"Generated workflows have layers on purpose:"}
      </Paragraph>

      <List>
        <Item><Code>agent-run.yml</Code>{" is the reusable runner: checkout, tools, credentials, home preparation, pi auth, session run, backup."}</Item>
        <Item><Code>&lt;agent&gt;.yml</Code>{" is the per-agent entrypoint: dispatch inputs plus concrete secret mapping."}</Item>
        <Item><Code>workflows.yaml</Code>{" adds schedules and mention wakes without hand-writing every workflow."}</Item>
        <Item><Code>agent:prepare</Code>{" belongs to the home repo, not shimmer. The home decides how to unlock notes, initialize modules, and warm local state."}</Item>
      </List>

      <Details summary="Why generated instead of hand-written?">
        <Paragraph>
          {"The contract is repetitive and security-sensitive. A hand-written copy eventually drifts: one agent misses a secret, another still runs a deprecated setup step, another forgets session backup. The generator makes the boring part identical and leaves home-specific setup to the home."}
        </Paragraph>
      </Details>
    </Section>

    <Section title="Development">
      <CodeBlock lang="bash">{`mise trust
mise install
mise run test
codebase lint "$PWD"
readme build --check
git diff --check`}</CodeBlock>

      <Paragraph>
        {"This README is generated from "}
        <Code>README.tsx</Code>
        {" with "}
        <Link href="https://github.com/KnickKnackLabs/readme">KnickKnackLabs/readme</Link>
        {". The repository currently asks codebase "}
        <Code>{toolVersion("shiv:codebase")}</Code>
        {" to run "}
        <Bold>{`${lints.length}`}</Bold>
        {" convention lints."}
      </Paragraph>

    </Section>

    <HR />

    <Center>
      <Sub>
        {"The plumbing should not be mysterious."}
      </Sub>
    </Center>
  </>
);

console.log(readme);
