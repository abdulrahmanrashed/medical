using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.MedicalRecords;
using Doctors.Domain.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Doctors.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class MedicalRecordsController : ControllerBase
{
    private readonly IMedicalRecordService _records;

    public MedicalRecordsController(IMedicalRecordService records)
    {
        _records = records;
    }

    [HttpGet]
    [Authorize(Roles = $"{AppRoles.Admin},{AppRoles.Doctor},{AppRoles.Patient}")]
    public async Task<ActionResult<IReadOnlyList<MedicalRecordDto>>> GetAll(CancellationToken cancellationToken)
    {
        return Ok(await _records.GetForCurrentUserAsync(cancellationToken));
    }

    [HttpGet("{id:int}")]
    [Authorize(Roles = $"{AppRoles.Admin},{AppRoles.Doctor},{AppRoles.Patient}")]
    public async Task<ActionResult<MedicalRecordDto>> GetById(int id, CancellationToken cancellationToken)
    {
        return Ok(await _records.GetByIdAsync(id, cancellationToken));
    }

    [HttpPost]
    [Authorize(Roles = AppRoles.Doctor)]
    public async Task<ActionResult<MedicalRecordDto>> Create([FromBody] CreateMedicalRecordDto dto, CancellationToken cancellationToken)
    {
        var created = await _records.CreateAsync(dto, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = AppRoles.Doctor)]
    public async Task<ActionResult<MedicalRecordDto>> Update(int id, [FromBody] UpdateMedicalRecordDto dto, CancellationToken cancellationToken)
    {
        return Ok(await _records.UpdateAsync(id, dto, cancellationToken));
    }

    [HttpPost("medications")]
    [Authorize(Roles = AppRoles.Doctor)]
    public async Task<ActionResult<MedicalRecordDto>> AddMedication([FromBody] AddMedicationDto dto, CancellationToken cancellationToken)
    {
        return Ok(await _records.AddMedicationAsync(dto, cancellationToken));
    }

    [HttpDelete("medications/{medicationId:int}")]
    [Authorize(Roles = AppRoles.Doctor)]
    public async Task<ActionResult<MedicalRecordDto>> RemoveMedication(int medicationId, CancellationToken cancellationToken)
    {
        return Ok(await _records.RemoveMedicationAsync(medicationId, cancellationToken));
    }

    [HttpPost("{id:int}/attachments")]
    [Authorize(Roles = AppRoles.Doctor)]
    [RequestSizeLimit(52_428_800)]
    public async Task<ActionResult<MedicalRecordDto>> UploadAttachment(
        int id,
        IFormFile file,
        [FromServices] IFileStorageService storage,
        CancellationToken cancellationToken)
    {
        if (file.Length == 0)
            return BadRequest(new { error = "File is empty." });

        await using var stream = file.OpenReadStream();
        var path = await storage.SaveAsync(stream, file.FileName, file.ContentType ?? "application/octet-stream", cancellationToken);
        var result = await _records.AddAttachmentAsync(id, path, file.FileName, file.ContentType ?? "application/octet-stream", file.Length, cancellationToken);
        return Ok(result);
    }
}
