export type Pagina =
  | 'central'
  | 'operacoes'
  | 'demandas'
  | 'processos-geral'
  | 'pessoas-geral'
  | 'documentos'
  | 'indicadores'
  | 'administracao'
  | 'empresas'
  | 'setores'
  | 'cargos'
  | 'pessoas'
  | 'perfis'
  | 'processos'
  | 'cadastro-operacoes'
  | 'responsabilidades'
  | 'recorrencias'

export type DadosUsuario = {
  pessoaId: string
  empresaId: string
  nome: string
  perfil: string
}

export type Execucao = {
  id: string
  titulo: string
  status: string
  prioridade: string
  data_prevista: string | null
  percentual_conclusao: number
}

export type Empresa = {
  id: string
  nome: string
  nome_fantasia: string | null
  cnpj: string | null
  ativo: boolean
}

export type Setor = {
  id: string
  nome: string
  descricao: string | null
  ativo: boolean
}

export type Cargo = {
  id: string
  nome: string
  descricao: string | null
  ativo: boolean
}

export type Pessoa = {
  id: string
  nome: string
  email: string | null
  setor_id: string | null
  cargo_id: string | null
  ativo: boolean
  setor?: { nome: string } | null
  cargo?: { nome: string } | null
}

export type Processo = {
  id: string
  setor_id: string
  nome: string
  descricao: string | null
  ativo: boolean
  setor?: { nome: string } | null
}

export type Operacao = {
  id: string
  setor_id: string
  processo_id: string
  nome: string
  descricao: string | null
  tipo: string
  prioridade: string
  tempo_estimado_minutos: number | null
  exige_conferencia: boolean
  exige_aprovacao: boolean
  exige_evidencia: boolean
  ativo: boolean
  setor?: { nome: string } | null
  processo?: { nome: string } | null
}

export type Responsabilidade = {
  id: string
  operacao_id: string
  pessoa_id: string
  papel: string
  principal: boolean
  ativo: boolean
  operacao?: { nome: string } | null
  pessoa?: { nome: string } | null
}

export type Recorrencia = {
  id: string
  operacao_id: string
  tipo_recorrencia: string
  dia_semana: number | null
  dia_mes: number | null
  data_especifica: string | null
  hora_prevista: string | null
  prazo_minutos: number | null
  sla_minutos: number | null
  ativo: boolean
  operacao?: { nome: string } | null
}

export type Perfil = {
  id: string
  nome: string
  descricao: string | null
}

export type UsuarioAcesso = {
  id: string
  pessoa_id: string
  perfil_id: string
  ativo: boolean
  pessoa?: { nome: string; email: string | null } | null
  perfil?: { nome: string } | null
}