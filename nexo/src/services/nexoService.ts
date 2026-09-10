import { supabase } from '../lib/supabase'

export async function buscarUsuarioAtual() {
  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) return null

  const { data, error } = await supabase
    .from('usuarios')
    .select(`
      pessoa_id,
      pessoa:pessoas (
        nome,
        empresa_id
      ),
      perfil:perfis (
        nome
      )
    `)
    .eq('id', user.id)
    .single()

  if (error) throw error

  const registro: any = data

  return {
    pessoaId: registro.pessoa_id,
    empresaId: registro.pessoa.empresa_id,
    nome: registro.pessoa.nome,
    perfil: registro.perfil.nome,
  }
}

export async function buscarExecucoes(pessoaId: string) {
  const { data, error } = await supabase
    .from('execucoes')
    .select(`
      id,
      titulo,
      status,
      prioridade,
      data_prevista,
      percentual_conclusao
    `)
    .eq('responsavel_id', pessoaId)
    .neq('status', 'CONCLUIDA')
    .neq('status', 'CANCELADA')
    .order('data_prevista', { ascending: true })

  if (error) throw error
  return data || []
}

export async function buscarEmpresa(id: string) {
  const { data, error } = await supabase
    .from('empresas')
    .select('id,nome,nome_fantasia,cnpj,ativo')
    .eq('id', id)
    .single()

  if (error) throw error
  return data
}

export async function atualizarEmpresa(id: string, valores: any) {
  const { error } = await supabase
    .from('empresas')
    .update({
      ...valores,
      updated_at: new Date().toISOString(),
    })
    .eq('id', id)

  if (error) throw error
}

export async function listarSetores(empresaId: string) {
  const { data, error } = await supabase
    .from('setores')
    .select('id,nome,descricao,ativo')
    .eq('empresa_id', empresaId)
    .order('nome')

  if (error) throw error
  return data || []
}

export async function salvarSetor(
  empresaId: string,
  id: string | null,
  valores: any
) {
  if (id) {
    const { error } = await supabase
      .from('setores')
      .update({
        ...valores,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)

    if (error) throw error
    return
  }

  const { error } = await supabase.from('setores').insert({
    empresa_id: empresaId,
    ...valores,
    ativo: true,
  })

  if (error) throw error
}

export async function statusSetor(id: string, ativo: boolean) {
  const { error } = await supabase
    .from('setores')
    .update({
      ativo,
      updated_at: new Date().toISOString(),
    })
    .eq('id', id)

  if (error) throw error
}

export async function listarCargos(empresaId: string) {
  const { data, error } = await supabase
    .from('cargos')
    .select('id,nome,descricao,ativo')
    .eq('empresa_id', empresaId)
    .order('nome')

  if (error) throw error
  return data || []
}

export async function salvarCargo(
  empresaId: string,
  id: string | null,
  valores: any
) {
  if (id) {
    const { error } = await supabase
      .from('cargos')
      .update({
        ...valores,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)

    if (error) throw error
    return
  }

  const { error } = await supabase.from('cargos').insert({
    empresa_id: empresaId,
    ...valores,
    ativo: true,
  })

  if (error) throw error
}

export async function statusCargo(id: string, ativo: boolean) {
  const { error } = await supabase
    .from('cargos')
    .update({
      ativo,
      updated_at: new Date().toISOString(),
    })
    .eq('id', id)

  if (error) throw error
}

export async function listarPessoas(empresaId: string) {
  const { data, error } = await supabase
    .from('pessoas')
    .select(`
      id,
      nome,
      email,
      setor_id,
      cargo_id,
      ativo,
      setor:setores(nome),
      cargo:cargos(nome)
    `)
    .eq('empresa_id', empresaId)
    .order('nome')

  if (error) throw error
  return data || []
}

export async function salvarPessoa(
  empresaId: string,
  id: string | null,
  valores: any
) {
  if (id) {
    const { error } = await supabase
      .from('pessoas')
      .update({
        ...valores,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)

    if (error) throw error
    return
  }

  const { error } = await supabase.from('pessoas').insert({
    empresa_id: empresaId,
    ...valores,
    ativo: true,
  })

  if (error) throw error
}

export async function statusPessoa(id: string, ativo: boolean) {
  const { error } = await supabase
    .from('pessoas')
    .update({
      ativo,
      updated_at: new Date().toISOString(),
    })
    .eq('id', id)

  if (error) throw error
}

export async function listarProcessos(empresaId: string) {
  const { data, error } = await supabase
    .from('processos')
    .select(`
      id,
      setor_id,
      nome,
      descricao,
      ativo,
      setor:setores(nome)
    `)
    .eq('empresa_id', empresaId)
    .order('nome')

  if (error) throw error
  return data || []
}

export async function salvarProcesso(
  empresaId: string,
  id: string | null,
  valores: any
) {
  if (id) {
    const { error } = await supabase
      .from('processos')
      .update({
        ...valores,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)

    if (error) throw error
    return
  }

  const { error } = await supabase.from('processos').insert({
    empresa_id: empresaId,
    ...valores,
    ativo: true,
  })

  if (error) throw error
}

export async function statusProcesso(id: string, ativo: boolean) {
  const { error } = await supabase
    .from('processos')
    .update({
      ativo,
      updated_at: new Date().toISOString(),
    })
    .eq('id', id)

  if (error) throw error
}

export async function listarOperacoes(empresaId: string) {
  const { data, error } = await supabase
    .from('operacoes')
    .select(`
      id,
      setor_id,
      processo_id,
      nome,
      descricao,
      tipo,
      prioridade,
      tempo_estimado_minutos,
      exige_conferencia,
      exige_aprovacao,
      exige_evidencia,
      ativo,
      setor:setores(nome),
      processo:processos(nome)
    `)
    .eq('empresa_id', empresaId)
    .order('nome')

  if (error) throw error
  return data || []
}

export async function salvarOperacao(
  empresaId: string,
  id: string | null,
  valores: any
) {
  if (id) {
    const { error } = await supabase
      .from('operacoes')
      .update({
        ...valores,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)

    if (error) throw error
    return
  }

  const { error } = await supabase.from('operacoes').insert({
    empresa_id: empresaId,
    ...valores,
    ativo: true,
  })

  if (error) throw error
}

export async function statusOperacao(id: string, ativo: boolean) {
  const { error } = await supabase
    .from('operacoes')
    .update({
      ativo,
      updated_at: new Date().toISOString(),
    })
    .eq('id', id)

  if (error) throw error
}

export async function listarResponsabilidades(empresaId: string) {
  const { data, error } = await supabase
    .from('operacao_responsaveis')
    .select(`
      id,
      operacao_id,
      pessoa_id,
      papel,
      principal,
      ativo,
      operacao:operacoes!inner(nome,empresa_id),
      pessoa:pessoas(nome)
    `)
    .eq('operacao.empresa_id', empresaId)

  if (error) throw error
  return data || []
}

export async function salvarResponsabilidade(
  id: string | null,
  valores: any
) {
  if (id) {
    const { error } = await supabase
      .from('operacao_responsaveis')
      .update({
        ...valores,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)

    if (error) throw error
    return
  }

  const { error } = await supabase
    .from('operacao_responsaveis')
    .insert({
      ...valores,
      ativo: true,
    })

  if (error) throw error
}

export async function statusResponsabilidade(
  id: string,
  ativo: boolean
) {
  const { error } = await supabase
    .from('operacao_responsaveis')
    .update({
      ativo,
      updated_at: new Date().toISOString(),
    })
    .eq('id', id)

  if (error) throw error
}

export async function listarRecorrencias(empresaId: string) {
  const { data, error } = await supabase
    .from('operacao_recorrencias')
    .select(`
      id,
      operacao_id,
      tipo_recorrencia,
      dia_semana,
      dia_mes,
      data_especifica,
      hora_prevista,
      prazo_minutos,
      sla_minutos,
      ativo,
      operacao:operacoes!inner(nome,empresa_id)
    `)
    .eq('operacao.empresa_id', empresaId)

  if (error) throw error
  return data || []
}

export async function salvarRecorrencia(
  id: string | null,
  valores: any
) {
  if (id) {
    const { error } = await supabase
      .from('operacao_recorrencias')
      .update({
        ...valores,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)

    if (error) throw error
    return
  }

  const { error } = await supabase
    .from('operacao_recorrencias')
    .insert({
      ...valores,
      ativo: true,
    })

  if (error) throw error
}

export async function statusRecorrencia(
  id: string,
  ativo: boolean
) {
  const { error } = await supabase
    .from('operacao_recorrencias')
    .update({
      ativo,
      updated_at: new Date().toISOString(),
    })
    .eq('id', id)

  if (error) throw error
}

export async function listarPerfis() {
  const { data, error } = await supabase
    .from('perfis')
    .select('id,nome,descricao')
    .order('nome')

  if (error) throw error
  return data || []
}

export async function listarUsuariosEmpresa(empresaId: string) {
  const { data, error } = await supabase
    .from('usuarios')
    .select(`
      id,
      pessoa_id,
      perfil_id,
      ativo,
      pessoa:pessoas!inner(nome,email,empresa_id),
      perfil:perfis(nome)
    `)
    .eq('pessoa.empresa_id', empresaId)

  if (error) throw error
  return data || []
}

export async function atualizarAcesso(
  usuarioId: string,
  perfilId: string,
  ativo: boolean
) {
  const { error } = await supabase
    .from('usuarios')
    .update({
      perfil_id: perfilId,
      ativo,
      updated_at: new Date().toISOString(),
    })
    .eq('id', usuarioId)

  if (error) throw error
}