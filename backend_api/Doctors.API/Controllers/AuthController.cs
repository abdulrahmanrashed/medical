using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Auth;
using Doctors.Domain.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Doctors.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _auth;

    public AuthController(IAuthService auth)
    {
        _auth = auth;
    }

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponseDto>> Login([FromBody] LoginRequestDto request, CancellationToken cancellationToken)
    {
        var result = await _auth.LoginAsync(request, cancellationToken);
        return Ok(result);
    }

    [HttpPost("register/patient")]
    [AllowAnonymous]
    public async Task<ActionResult<AuthResponseDto>> RegisterPatient([FromBody] RegisterPatientRequestDto request, CancellationToken cancellationToken)
    {
        var result = await _auth.RegisterPatientAsync(request, cancellationToken);
        return Ok(result);
    }

    [HttpPost("register/doctor")]
    [Authorize(Roles = AppRoles.ClinicAdmin)]
    public async Task<ActionResult<AuthResponseDto>> RegisterDoctor([FromBody] RegisterDoctorRequestDto request, CancellationToken cancellationToken)
    {
        var result = await _auth.RegisterDoctorAsync(request, cancellationToken);
        return Ok(result);
    }

    [HttpPost("register/reception")]
    [Authorize(Roles = AppRoles.ClinicAdmin)]
    public async Task<ActionResult<AuthResponseDto>> RegisterReception([FromBody] RegisterReceptionRequestDto request, CancellationToken cancellationToken)
    {
        var result = await _auth.RegisterReceptionAsync(request, cancellationToken);
        return Ok(result);
    }
}
