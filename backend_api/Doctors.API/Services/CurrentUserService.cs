using System.Security.Claims;
using Doctors.Application.Common.Interfaces;
using Doctors.Infrastructure.Identity;

namespace Doctors.API.Services;

public class CurrentUserService : ICurrentUserService
{
    private readonly IHttpContextAccessor _http;

    public CurrentUserService(IHttpContextAccessor http)
    {
        _http = http;
    }

    private ClaimsPrincipal? User => _http.HttpContext?.User;

    public string? UserId => User?.FindFirstValue(ClaimTypes.NameIdentifier);

    public bool IsInRole(string role) => User?.IsInRole(role) ?? false;

    public int? GetDoctorId() => ParseInt(User?.FindFirstValue(JwtClaimNames.DoctorId));

    public Guid? GetPatientId()
    {
        var v = User?.FindFirstValue(JwtClaimNames.PatientId);
        return Guid.TryParse(v, out var g) ? g : null;
    }

    public int? GetAssignedClinicId() => ParseInt(User?.FindFirstValue(JwtClaimNames.AssignedClinicId));

    private static int? ParseInt(string? value) =>
        int.TryParse(value, out var id) ? id : null;
}
