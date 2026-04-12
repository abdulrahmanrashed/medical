using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.MedicalFiles;
using Doctors.Domain.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Doctors.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class MedicalFilesController : ControllerBase
{
    private readonly IMedicalFileService _files;

    public MedicalFilesController(IMedicalFileService files)
    {
        _files = files;
    }

    /// <summary>Patient: upload a lab result or image; optional appointment link.</summary>
    [HttpPost]
    [Authorize(Roles = AppRoles.Patient)]
    [RequestSizeLimit(52_428_800)]
    public async Task<ActionResult<MedicalFileDto>> Upload(
        [FromQuery] int? appointmentId,
        IFormFile file,
        CancellationToken cancellationToken)
    {
        if (file.Length == 0)
            return BadRequest(new { error = "File is empty." });

        await using var stream = file.OpenReadStream();
        var dto = await _files.UploadForCurrentPatientAsync(
            appointmentId,
            stream,
            file.FileName,
            file.ContentType ?? "application/octet-stream",
            file.Length,
            cancellationToken);
        return Ok(dto);
    }

    [HttpGet("me")]
    [Authorize(Roles = AppRoles.Patient)]
    public async Task<ActionResult<IReadOnlyList<MedicalFileDto>>> GetMine(CancellationToken cancellationToken)
    {
        return Ok(await _files.GetMineAsync(cancellationToken));
    }
}
