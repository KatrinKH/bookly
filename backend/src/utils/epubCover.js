const AdmZip = require('adm-zip');
const xml2js = require('xml2js');
const path = require('path');
const fs = require('fs');

// EPUB — это ZIP-архив. Обложка обычно указана в манифесте content.opf
// одним из двух стандартных способов:
//  1) <meta name="cover" content="cover-image-id"/> + соответствующий <item> в manifest
//  2) <item properties="cover-image" href="..."/> (более новый EPUB3-способ)
// Эта функция распаковывает архив, находит content.opf, парсит манифест
// и возвращает буфер с изображением обложки (или null, если не нашли).
async function extractEpubCover(epubFilePath) {
  try {
    const zip = new AdmZip(epubFilePath);
    const entries = zip.getEntries();

    // Находим container.xml, который указывает путь к content.opf
    const containerEntry = entries.find((e) => e.entryName.endsWith('META-INF/container.xml'));
    if (!containerEntry) return null;

    const containerXml = await xml2js.parseStringPromise(containerEntry.getData().toString('utf8'));
    const opfPath = containerXml.container.rootfiles[0].rootfile[0].$['full-path'];

    const opfEntry = entries.find((e) => e.entryName === opfPath);
    if (!opfEntry) return null;

    const opfXml = await xml2js.parseStringPromise(opfEntry.getData().toString('utf8'));
    const manifestItems = opfXml.package.manifest[0].item;
    const metadata = opfXml.package.metadata[0];

    const opfDir = path.dirname(opfPath);
    let coverHref = null;

    // Способ 1 (EPUB2): <meta name="cover" content="some-id"/>
    if (metadata.meta) {
      const coverMeta = metadata.meta.find((m) => m.$.name === 'cover');
      if (coverMeta) {
        const coverId = coverMeta.$.content;
        const coverItem = manifestItems.find((item) => item.$.id === coverId);
        if (coverItem) coverHref = coverItem.$.href;
      }
    }

    // Способ 2 (EPUB3): <item properties="cover-image" href="..."/>
    if (!coverHref) {
      const coverItem = manifestItems.find(
        (item) => item.$.properties && item.$.properties.includes('cover-image')
      );
      if (coverItem) coverHref = coverItem.$.href;
    }

    if (!coverHref) return null;

    // href в манифесте указан относительно папки content.opf
    const coverFullPath = opfDir === '.' ? coverHref : path.join(opfDir, coverHref);
    const coverEntry = entries.find((e) => e.entryName === coverFullPath.replace(/\\/g, '/'));

    if (!coverEntry) return null;

    return {
      data: coverEntry.getData(),
      ext: path.extname(coverHref) || '.jpg',
    };
  } catch (err) {
    console.error('Не удалось извлечь обложку из EPUB:', err.message);
    return null;
  }
}

// Сохраняет извлечённую обложку в указанную папку и возвращает путь к файлу
function saveCoverToFile(coverData, coversDir, baseName) {
  if (!coverData) return null;

  const fileName = `${baseName}${coverData.ext}`;
  const filePath = path.join(coversDir, fileName);

  fs.writeFileSync(filePath, coverData.data);
  return filePath;
}

module.exports = { extractEpubCover, saveCoverToFile };
