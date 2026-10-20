const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');

const library = readFileSync(path.join(__dirname, '../assets/init.js'), 'utf8');
// The failing initialization from the native source revision in the log.
const fixture = `class ComicWalker extends ComicSource {
    key = 'comic_walker';
    latestVersion = '1.4.13';
    tokenRefreshes = 0;
    async refreshToken() { this.tokenRefreshes++; await createGuestToken(); }
    async init() {
        const resp = await Network.get('https://itunes.apple.com/lookup?bundleId=jp.co.bookwalker.cwapp.ios&country=jp');
        if (resp.status == 200) {
            response = JSON.parse(resp.body);
            this.latestVersion = response.version;
        }
        await this.refreshToken();
    }
}`;

function runtime(get, createGuestToken = async () => {}) {
    const context = vm.createContext({ get, createGuestToken });
    vm.runInContext(library, context);
    vm.runInContext(`Network.get = get; ${fixture}
        globalThis.source = ComicSource.applyCompatibilityFixes(new ComicWalker());`, context);
    return context;
}

test('ComicWalker initializes anonymously using the nested iTunes version', async () => {
    const context = runtime(async () => ({
        status: 200, body: JSON.stringify({ resultCount: 1, results: [{ version: '1.5.0' }] }),
    }));
    await context.source.init();
    assert.equal(context.source.latestVersion, '1.5.0');
    assert.equal(context.source.tokenRefreshes, 1);
    assert.equal(vm.runInContext('typeof response', context), 'undefined');
});

for (const [name, get] of [
    ['no results', async () => ({ status: 200, body: '{"results":[]}' })],
    ['missing results', async () => ({ status: 200, body: '{}' })],
    ['invalid version', async () => ({ status: 200, body: '{"results":[{"version":null}]}' })],
    ['empty version', async () => ({ status: 200, body: '{"results":[{"version":" "}]}' })],
    ['invalid JSON', async () => ({ status: 200, body: '<html>unavailable</html>' })],
    ['HTTP failure', async () => ({ status: 503 })],
    ['network failure', async () => { throw new Error('offline'); }],
]) {
    test(`ComicWalker still creates a guest token after ${name}`, async () => {
        const { source } = runtime(get);
        await source.init();
        assert.equal(source.latestVersion, '1.4.13');
        assert.equal(source.tokenRefreshes, 1);
    });
}

test('guest token errors remain visible to the caller', async () => {
    const { source } = runtime(
        async () => ({ status: 503 }),
        async () => { throw new Error('token service unavailable'); },
    );
    await assert.rejects(source.init(), /token service unavailable/);
});

test('the compatibility fix leaves other sources and corrected scripts intact', () => {
    const context = runtime(async () => ({ status: 503 }));
    assert.equal(vm.runInContext(`(() => {
        const unrelated = new ComicWalker();
        unrelated.key = 'another_source';
        const original = unrelated.init;
        ComicSource.applyCompatibilityFixes(unrelated);
        return unrelated.init === original;
    })()`, context), true);
    assert.equal(vm.runInContext(`(() => {
        const corrected = new ComicWalker();
        corrected.init = async function () { this.latestVersion = '2.0'; };
        const original = corrected.init;
        ComicSource.applyCompatibilityFixes(corrected);
        return corrected.init === original;
    })()`, context), true);
    assert.equal(vm.runInContext(`(() => {
        const original = source.init;
        ComicSource.applyCompatibilityFixes(source);
        return source.init === original;
    })()`, context), true);
});
