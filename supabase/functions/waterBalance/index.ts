import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

// 声明 Deno 全局类型
declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface WaterBalanceQuery {
  groupName: string;
  statDate: string;
}

interface WaterBalanceItem {
  id: number;
  pid: number;
  name: string;
  waterVolume: number;
  waterAmount: number;
  path?: string;
}

interface WaterBalanceTreeNode {
  id: number;
  pid: number;
  name: string;
  waterVolume: number;
  waterAmount: number;
  path: string;
  children?: WaterBalanceTreeNode[];
}

interface WaterBalanceResponse {
  data: WaterBalanceTreeNode[];
  success: boolean;
  message?: string;
}

// 构建树形结构的函数
function buildTree(items: WaterBalanceItem[]): WaterBalanceTreeNode[] {
  const itemMap = new Map<number, WaterBalanceTreeNode>();
  const rootNodes: WaterBalanceTreeNode[] = [];

  // 首先创建所有节点的映射
  items.forEach(item => {
    itemMap.set(item.id, {
      id: item.id,
      pid: item.pid,
      name: item.name,
      waterVolume: item.waterVolume,
      waterAmount: item.waterAmount,
      path: '', // 初始化为空，后面会计算
      children: []
    });
  });

  // 构建树形结构并计算路径
  items.forEach(item => {
    const node = itemMap.get(item.id)!;
    
    if (item.pid === 0 || !itemMap.has(item.pid)) {
      // 根节点，路径就是节点名称
      node.path = node.name;
      rootNodes.push(node);
    } else {
      // 子节点
      const parent = itemMap.get(item.pid);
      if (parent) {
        if (!parent.children) {
          parent.children = [];
        }
        parent.children.push(node);
      }
    }
  });

  // 递归计算所有节点的路径
  function calculatePaths(nodes: WaterBalanceTreeNode[], parentPath: string = '') {
    nodes.forEach(node => {
      if (parentPath) {
        node.path = `${parentPath}/${node.name}`;
      } else {
        node.path = node.name;
      }
      
      if (node.children && node.children.length > 0) {
        calculatePaths(node.children, node.path);
      }
    });
  }

  calculatePaths(rootNodes);

  return rootNodes;
}

serve(async (req: Request) => {
  // 处理 CORS 预检请求
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 获取环境变量
    const supabaseUrl = "http://10.38.245.59:8000"//Deno.env.get('SUPABASE_URL')
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')

    // 打印环境变量（注意：生产环境中应该隐藏敏感信息）
    console.log('环境变量检查:');
    console.log('SUPABASE_URL:', supabaseUrl ? `${supabaseUrl.substring(0, 20)}...` : '未设置');
    console.log('SUPABASE_ANON_KEY:', supabaseAnonKey ? `${supabaseAnonKey.substring(0, 10)}...` : '未设置');

    if (!supabaseUrl || !supabaseAnonKey) {
      throw new Error('Missing Supabase environment variables')
    }

    // 创建 Supabase 客户端
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      db: { schema: 'leak_detection' }
    })

    // 解析请求参数
    let groupName = '默认分组';
    let statDate = '2024-01-01';
    
    try {
      const bodyText = await req.text();
      if (bodyText && bodyText.trim() !== '') {
        const body = JSON.parse(bodyText);
        groupName = body.groupName || groupName;
        statDate = body.statDate || statDate;
      }
    } catch (parseError) {
      console.error('JSON 解析错误:', parseError);
      return new Response(
        JSON.stringify({
          success: false,
          data: [],
          message: '请求参数格式错误，请检查 JSON 格式'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        }
      );
    }

    // 执行查询
    console.log('开始查询数据库，参数:', { groupName, statDate });

    const { data, error } = await supabase
      .from('dim_water_balance')
      .select(`
        id,
        pid,
        name,
        fact_water_balance!inner(
          water_volume,
          water_amount
        )
      `)
      .eq('group_name', groupName)
      .eq('fact_water_balance.stat_date', statDate)

    console.log('查询结果:', { data: data?.length || 0, error });

    if (error) {
        throw new Error(`查询失败: ${error.message}`)
    }

    // 转换数据格式 - 使用类型安全的方式
    const items: WaterBalanceItem[] = data?.map((item: any) => {
      const factData = Array.isArray(item.fact_water_balance) 
        ? item.fact_water_balance[0] 
        : item.fact_water_balance;
      
      return {
        id: item.id,
        pid: item.pid,
        name: item.name,
        waterVolume: factData?.water_volume || 0,
        waterAmount: factData?.water_amount || 0
      };
    }) || []

    console.log('转换后的数据项数:', items.length);

    // 构建树形结构
    const treeData = buildTree(items)

    console.log('构建的树形结构根节点数:', treeData.length);

    const response: WaterBalanceResponse = {
      data: treeData,
      success: true
    }

    return new Response(
      JSON.stringify(response),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error: unknown) {
    console.error('水平衡查询失败:', {
      error: error,
      errorType: typeof error,
      errorConstructor: error?.constructor?.name,
      stack: error instanceof Error ? error.stack : undefined,
      timestamp: new Date().toISOString(),
      requestInfo: {
        method: 'POST',
        endpoint: '/functions/v1/water_balance'
      }
    });
    
    const errorMessage = error instanceof Error 
      ? `${error.message}${error.stack ? `\nStack: ${error.stack}` : ''}`
      : `未知错误: ${String(error)}`;
    
    const errorResponse: WaterBalanceResponse = {
      data: [],
      success: false,
      message: errorMessage
    }

    return new Response(
      JSON.stringify(errorResponse),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})
