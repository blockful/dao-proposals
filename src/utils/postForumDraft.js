// Saves each forum-post.md given as an argument as a reply draft on its Discourse topic, under the
// account that owns the DAO's forum API key. Nothing is published: someone logs into that account,
// opens the topic, reviews the draft in the composer, and posts it.
//
// A post opts in with frontmatter naming its topic; files without it are skipped:
//
//   ---
//   topic: https://www.comp.xyz/t/some-proposal/12345
//   ---
//
// Env: <DAO>_FORUM_API_KEY and <DAO>_FORUM_USERNAME, where DAO is the dao-registry.json key
// upper-cased with - as _. COMMIT_SHA fills the COMMIT_HASH / SHORT_HASH placeholders.
// DRY_RUN=1 prints the draft instead of sending it.

const fs = require('fs');
const path = require('path');

const registry = JSON.parse(fs.readFileSync(path.resolve(__dirname, '..', 'dao-registry.json'), 'utf-8'));

function parse(file) {
    const text = fs.readFileSync(file, 'utf-8');
    const front = text.match(/^---\n([\s\S]*?)\n---\n/);
    if (!front) return null;

    const topicUrl = front[1].match(/^topic:\s*(\S+)\s*$/m)?.[1];
    const topicId = topicUrl?.match(/\/t\/(?:[^/]+\/)?(\d+)/)?.[1];
    if (!topicId) throw new Error(`${file}: frontmatter needs "topic: <forum topic URL>"`);

    const [key, dao] = Object.entries(registry.daos).find(([, d]) => file.startsWith(d.basePath + '/')) || [];
    if (!dao?.forumUrl) throw new Error(`${file}: no forumUrl for this DAO in dao-registry.json`);

    // The API key only ever goes to the forum the registry names, whatever the post links to.
    const origin = new URL(dao.forumUrl).origin;
    if (new URL(topicUrl).origin !== origin) throw new Error(`${file}: topic ${topicUrl} is not on ${origin}`);

    const sha = process.env.COMMIT_SHA || '';
    const reply = text
        .slice(front[0].length)
        .trim()
        .replaceAll('COMMIT_HASH', sha)
        .replaceAll('SHORT_HASH', sha.slice(0, 7));
    if (/COMMIT_HASH|SHORT_HASH/.test(text) && !sha) throw new Error(`${file}: set COMMIT_SHA to fill the placeholders`);

    return { key, origin, topicId, reply };
}

async function saveDraft({ key, origin, topicId, reply }) {
    const env = key.toUpperCase().replaceAll('-', '_');
    const apiKey = process.env[`${env}_FORUM_API_KEY`];
    const username = process.env[`${env}_FORUM_USERNAME`];
    if (!apiKey || !username) throw new Error(`${env}_FORUM_API_KEY and ${env}_FORUM_USERNAME must be set`);

    const headers = { 'Api-Key': apiKey, 'Api-Username': username };
    const draftKey = `topic_${topicId}`;

    // Discourse rejects a draft whose sequence is behind the stored one, so read it first.
    // ponytail: overwrites any unpublished draft this account has on the topic.
    const current = await fetch(`${origin}/drafts/${draftKey}.json`, { headers });
    if (!current.ok) throw new Error(`GET draft ${draftKey}: ${current.status} ${await current.text()}`);
    const { draft_sequence } = await current.json();

    const res = await fetch(`${origin}/drafts.json`, {
        method: 'POST',
        headers,
        body: new URLSearchParams({
            draft_key: draftKey,
            sequence: String(draft_sequence),
            data: JSON.stringify({ reply, action: 'reply', archetypeId: 'regular', composerTime: 0, typingTime: 0 }),
        }),
    });
    if (!res.ok) throw new Error(`POST draft ${draftKey}: ${res.status} ${await res.text()}`);
    console.log(`::notice::Draft saved for @${username} on ${origin}/t/${topicId} — review and post it there`);
}

async function main() {
    const files = process.argv.slice(2);
    let failed = false;
    for (const file of files) {
        try {
            const post = parse(file);
            if (!post) {
                console.log(`${file}: no topic frontmatter, skipped`);
            } else if (process.env.DRY_RUN) {
                console.log(`--- ${post.origin}/t/${post.topicId} (${post.key})\n${post.reply}\n`);
            } else {
                await saveDraft(post);
            }
        } catch (e) {
            console.log(`::error::${e.message}`);
            failed = true;
        }
    }
    process.exit(failed ? 1 : 0);
}

main();
