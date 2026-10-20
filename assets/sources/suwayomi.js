// Zeitlind bridge for the Suwayomi REST v1 API. Extensions run on your server.
class ZeitlindSuwayomi extends ComicSource {
    name = __ZEITLIND_SOURCE_NAME__;
    key = __ZEITLIND_SOURCE_KEY__;
    version = "1.0.0";
    minAppVersion = "2.1.0";
    server = __ZEITLIND_SERVER__;
    remoteSource = __ZEITLIND_SOURCE_ID__;

    headers() {
        const authorization = this.loadData("bridgeAuthorization");
        return authorization ? {Authorization: authorization} : {};
    }

    async request(path) {
        const response = await Network.get(`${this.server}/api/v1/${path}`, this.headers());
        if (response.status !== 200) throw `Suwayomi HTTP ${response.status}`;
        return JSON.parse(response.body);
    }

    cover(id) { return `${this.server}/api/v1/manga/${id}/thumbnail`; }

    list(result, page) {
        if (!Array.isArray(result.mangaList)) throw "Invalid Suwayomi manga list";
        return {
            comics: result.mangaList.map(manga => new Comic({
                id: String(manga.id), title: manga.title,
                subtitle: manga.author || manga.artist || "", cover: this.cover(manga.id),
            })),
            maxPage: result.hasNextPage ? page + 1 : page,
        };
    }

    explore = [{
        title: `${this.name} · Popular`, type: "multiPageComicList",
        load: async page => this.list(await this.request(`source/${this.remoteSource}/popular/${page}`), page),
    }];

    search = {
        load: async (keyword, options, page) => this.list(await this.request(
            `source/${this.remoteSource}/search?searchTerm=${encodeURIComponent(keyword)}&pageNum=${page}`
        ), page),
    };

    comic = {
        loadInfo: async id => {
            const manga = await this.request(`manga/${encodeURIComponent(id)}?onlineFetch=true`);
            const chapters = await this.request(`manga/${encodeURIComponent(id)}/chapters?onlineFetch=true`);
            if (!Array.isArray(chapters)) throw "Invalid Suwayomi chapter list";
            const ordered = chapters.slice().sort((a, b) => a.index - b.index);
            const chapterMap = {};
            for (const chapter of ordered) chapterMap[String(chapter.index)] = chapter.name;
            return new ComicDetails({
                title: manga.title, subtitle: manga.author || manga.artist || "",
                cover: this.cover(id), description: manga.description || "",
                tags: {Genre: manga.genre || []}, chapters: chapterMap,
                url: manga.realUrl || this.server,
            });
        },
        loadEp: async (id, chapter) => {
            const info = await this.request(`manga/${encodeURIComponent(id)}/chapter/${encodeURIComponent(chapter)}?onlineFetch=true`);
            if (!Number.isInteger(info.pageCount) || info.pageCount < 0) throw "Suwayomi returned no page count";
            return Array.from({length: info.pageCount}, (_, index) =>
                `${this.server}/api/v1/manga/${encodeURIComponent(id)}/chapter/${encodeURIComponent(chapter)}/page/${index}`);
        },
        onImageLoad: url => new ImageLoadingConfig({url, headers: url.startsWith(`${this.server}/api/`) ? this.headers() : {}}),
        onThumbnailLoad: url => new ImageLoadingConfig({url, headers: url.startsWith(`${this.server}/api/`) ? this.headers() : {}}),
    };
}
