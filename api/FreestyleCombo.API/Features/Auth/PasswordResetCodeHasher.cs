using System.Security.Cryptography;
using System.Text;

namespace FreestyleCombo.API.Features.Auth;

internal static class PasswordResetCodeHasher
{
    public static string Hash(string code) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(code)));
}
