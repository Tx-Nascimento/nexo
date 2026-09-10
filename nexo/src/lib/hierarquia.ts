export const PERFIS_EMPRESA = ['ADMIN', 'DIRETORIA', 'AUDITOR']
export const PERFIS_SETOR = ['LIDER', 'GESTOR', 'GERENTE']

export function escopoPerfil(
  perfil: string,
  pessoaId: string,
  setorId: string | null,
  alvoPessoaId: string,
  alvoSetorId: string | null
) {
  if (PERFIS_EMPRESA.includes(perfil)) return true
  if (alvoPessoaId === pessoaId) return true
  if (PERFIS_SETOR.includes(perfil)) return !!setorId && alvoSetorId === setorId
  return false
}

export function podeVerEmpresa(perfil: string) {
  return PERFIS_EMPRESA.includes(perfil)
}
