using Doctors.Application.DTOs.Auth;

namespace Doctors.Application.Common.Interfaces;

public interface IAuthService
{
    Task<AuthResponseDto> LoginAsync(LoginRequestDto request, CancellationToken cancellationToken = default);
    Task<AuthResponseDto> RegisterPatientAsync(RegisterPatientRequestDto request, CancellationToken cancellationToken = default);
    Task<AuthResponseDto> RegisterDoctorAsync(RegisterDoctorRequestDto request, CancellationToken cancellationToken = default);
    Task<AuthResponseDto> RegisterReceptionAsync(RegisterReceptionRequestDto request, CancellationToken cancellationToken = default);
}
