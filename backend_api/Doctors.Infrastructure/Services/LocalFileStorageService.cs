using Doctors.Application.Common.Interfaces;
using Microsoft.AspNetCore.Hosting;

namespace Doctors.Infrastructure.Services;

public class LocalFileStorageService : IFileStorageService
{
    private readonly IWebHostEnvironment _env;
    private const string UploadSubfolder = "uploads";

    public LocalFileStorageService(IWebHostEnvironment env)
    {
        _env = env;
    }

    public async Task<string> SaveAsync(Stream fileStream, string originalFileName, string contentType, CancellationToken cancellationToken = default)
    {
        var webRoot = _env.WebRootPath ?? Path.Combine(_env.ContentRootPath, "wwwroot");
        Directory.CreateDirectory(webRoot);

        var safeName = Path.GetFileName(originalFileName);
        var ext = Path.GetExtension(safeName);
        var unique = $"{Guid.NewGuid():N}{ext}";
        var dayFolder = DateTime.UtcNow.ToString("yyyyMMdd");
        var relative = Path.Combine(UploadSubfolder, dayFolder, unique).Replace('\\', '/');
        var physicalDir = Path.Combine(webRoot, UploadSubfolder, dayFolder);
        Directory.CreateDirectory(physicalDir);
        var physicalPath = Path.Combine(physicalDir, unique);
        await using var fs = File.Create(physicalPath);
        await fileStream.CopyToAsync(fs, cancellationToken);
        return relative.Replace('\\', '/');
    }

    public void DeleteIfExists(string relativePath)
    {
        if (string.IsNullOrWhiteSpace(relativePath))
            return;
        var root = _env.WebRootPath ?? Path.Combine(_env.ContentRootPath, "wwwroot");
        var full = Path.Combine(root, relativePath.Replace('/', Path.DirectorySeparatorChar));
        if (File.Exists(full))
            File.Delete(full);
    }
}
