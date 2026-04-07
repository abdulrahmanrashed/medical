using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Patients;
using Doctors.Domain.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Doctors.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PatientsController : ControllerBase
{
    private readonly IPatientService _patients;

    public PatientsController(IPatientService patients)
    {
        _patients = patients;
    }

    /// <summary>Anonymous: check phone for app registration (prefill DRAFT or signal COMPLETED).</summary>
    [HttpPost("public/registration-lookup")]
    [AllowAnonymous]
    public async Task<ActionResult<PatientRegistrationLookupResponseDto>> RegistrationLookup(
        [FromBody] PhoneRegistrationLookupDto dto,
        CancellationToken cancellationToken)
    {
        return Ok(await _patients.LookupForAppRegistrationAsync(dto.Phone, cancellationToken));
    }

    [HttpGet("me")]
    [Authorize(Roles = AppRoles.Patient)]
    public async Task<ActionResult<PatientDto>> GetMe(CancellationToken cancellationToken)
    {
        return Ok(await _patients.GetMyProfileAsync(cancellationToken));
    }

    [HttpGet]
    [Authorize(Roles = $"{AppRoles.Admin},{AppRoles.Reception}")]
    public async Task<ActionResult<IReadOnlyList<PatientDto>>> GetAll(CancellationToken cancellationToken)
    {
        return Ok(await _patients.GetAllAsync(cancellationToken));
    }

    [HttpGet("{id:guid}")]
    [Authorize(Roles = $"{AppRoles.Admin},{AppRoles.Reception},{AppRoles.Doctor}")]
    public async Task<ActionResult<PatientDto>> GetById(Guid id, CancellationToken cancellationToken)
    {
        return Ok(await _patients.GetByIdAsync(id, cancellationToken));
    }

    [HttpPost("draft")]
    [Authorize(Roles = $"{AppRoles.Admin},{AppRoles.Reception}")]
    public async Task<ActionResult<PatientDto>> CreateDraft([FromBody] CreateDraftPatientDto dto, CancellationToken cancellationToken)
    {
        return Ok(await _patients.CreateDraftAsync(dto, cancellationToken));
    }

    /// <summary>Scenario A: search by phone; if missing, create DRAFT with phone + name (same patient id forever).</summary>
    [HttpPost("reception/find-or-create-draft")]
    [Authorize(Roles = $"{AppRoles.Admin},{AppRoles.Reception}")]
    public async Task<ActionResult<PatientDto>> ReceptionFindOrCreateDraft(
        [FromBody] ReceptionFindOrCreatePatientDto dto,
        CancellationToken cancellationToken)
    {
        return Ok(await _patients.FindOrCreateDraftByPhoneAsync(dto, cancellationToken));
    }

    /// <summary>Reception/admin: patient by phone for appointment form (does not create a row).</summary>
    [HttpGet("reception/by-phone")]
    [Authorize(Roles = $"{AppRoles.Admin},{AppRoles.Reception}")]
    public async Task<ActionResult<PatientDto>> LookupByPhone([FromQuery] string phone, CancellationToken cancellationToken)
    {
        var found = await _patients.LookupByPhoneForReceptionAsync(phone, cancellationToken);
        if (found is null)
            return NotFound();
        return Ok(found);
    }

    [HttpPatch("me")]
    [Authorize(Roles = AppRoles.Patient)]
    public async Task<ActionResult<PatientDto>> UpdateMe(
        [FromBody] UpdatePatientProfileDto dto,
        CancellationToken cancellationToken)
    {
        return Ok(await _patients.UpdateMyProfileAsync(dto, cancellationToken));
    }

    [HttpPost("link-clinic")]
    [Authorize(Roles = $"{AppRoles.Patient},{AppRoles.Admin},{AppRoles.Reception}")]
    public async Task<ActionResult<PatientDto>> LinkClinic([FromBody] LinkPatientClinicDto dto, CancellationToken cancellationToken)
    {
        return Ok(await _patients.LinkToClinicAsync(dto, cancellationToken));
    }
}
