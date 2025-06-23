import relationalStore from '@ohos.data.relationalStore';
import common from '@ohos.app.ability.common';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * 账单数据接口
 */
export interface Bill {
  date: string;          // 日期
  type: '收入' | '支出';  // 收入/支出
  category: string;      // 类别
  amount: number;        // 金额
  remark?: string;       // 备注
}

/**
 * 包含ID的账单记录接口
 */
export interface BillRecord extends Bill {
  id: number;            // 数据库自增ID
}

/**
 * 查询账单选项接口
 */
export interface QueryBillOptions {
  type?: '收入' | '支出';
  startDate?: string;
  endDate?: string;
  sortBy?: 'date' | 'amount';
  sortOrder?: 'asc' | 'desc';
}

/**
 * 统计选项接口
 */
export interface StatisticsOptions {
  startDate?: string;
  endDate?: string;
}

/**
 * 类别统计结果接口
 */
export interface CategoryStatItem {
  category: string;
  total: number;
}

/**
 * 总统计结果接口
 */
export interface StatisticsResult {
  totalIncome: number;
  totalExpense: number;
}

/**
 * 账单数据库服务类
 */
export class BillDBService {
  private rdbStore: relationalStore.RdbStore | null = null;
  private readonly tableName: string = 'BILL';
  private readonly dbName: string = 'Bill.db';

  /**
   * 初始化数据库
   * @param context 应用上下文
   * @returns Promise<boolean> 是否初始化成功
   */
  async initDB(context: common.Context): Promise<boolean> {
    if (this.rdbStore !== null) {
      return true;
    }

    const config: relationalStore.StoreConfig = {
      name: this.dbName,
      securityLevel: relationalStore.SecurityLevel.S1
    };

    try {
      this.rdbStore = await relationalStore.getRdbStore(context, config);
      
      // 确保账单表已创建
      await this.ensureTableCreated();
      
      console.info('数据库初始化成功');
      return true;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`数据库初始化失败: ${error.message}`);
      return false;
    }
  }

  /**
   * 确保账单表已创建
   */
  private async ensureTableCreated(): Promise<void> {
    if (!this.rdbStore) {
      return;
    }

    const SQL_CREATE_TABLE = `
    CREATE TABLE IF NOT EXISTS ${this.tableName} (
      BILL_ID INTEGER PRIMARY KEY AUTOINCREMENT,
      DATE TEXT NOT NULL,
      TYPE TEXT CHECK(TYPE IN ('收入', '支出')),
      CATEGORY TEXT,
      AMOUNT REAL,
      REMARK TEXT
    )`;

    try {
      await this.rdbStore.executeSql(SQL_CREATE_TABLE);
      console.info('账单表创建成功或已存在');
    } catch (err) {
      const error = err as BusinessError;
      console.error(`创建账单表失败: ${error.message}`);
    }
  }

  /**
   * 添加账单
   * @param bill 账单数据
   * @returns Promise<number> 插入记录的ID，失败返回-1
   */
  async addBill(bill: Bill): Promise<number> {
    if (!this.rdbStore) {
      console.error('数据库未初始化');
      return -1;
    }

    const valuesBucket: relationalStore.ValuesBucket = {
      DATE: bill.date,
      TYPE: bill.type,
      CATEGORY: bill.category,
      AMOUNT: bill.amount,
      REMARK: bill.remark || ''
    };

    try {
      const rowId = await this.rdbStore.insert(this.tableName, valuesBucket);
      console.info(`添加账单成功，ID: ${rowId}`);
      return rowId;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`添加账单失败: ${error.message}`);
      return -1;
    }
  }

  /**
   * 删除账单
   * @param id 账单ID
   * @returns Promise<boolean> 是否删除成功
   */
  async deleteBill(id: number): Promise<boolean> {
    if (!this.rdbStore) {
      console.error('数据库未初始化');
      return false;
    }

    const predicates = new relationalStore.RdbPredicates(this.tableName);
    predicates.equalTo('BILL_ID', id);

    try {
      const deletedRows = await this.rdbStore.delete(predicates);
      console.info(`删除账单成功，影响行数: ${deletedRows}`);
      return deletedRows > 0;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`删除账单失败: ${error.message}`);
      return false;
    }
  }

  /**
   * 更新账单
   * @param id 账单ID
   * @param bill 更新的账单数据
   * @returns Promise<boolean> 是否更新成功
   */
  async updateBill(id: number, bill: Partial<Bill>): Promise<boolean> {
    if (!this.rdbStore) {
      console.error('数据库未初始化');
      return false;
    }

    const valuesBucket: relationalStore.ValuesBucket = {};

    if (bill.date !== undefined) valuesBucket.DATE = bill.date;
    if (bill.type !== undefined) valuesBucket.TYPE = bill.type;
    if (bill.category !== undefined) valuesBucket.CATEGORY = bill.category;
    if (bill.amount !== undefined) valuesBucket.AMOUNT = bill.amount;
    if (bill.remark !== undefined) valuesBucket.REMARK = bill.remark;

    const predicates = new relationalStore.RdbPredicates(this.tableName);
    predicates.equalTo('BILL_ID', id);

    try {
      const updatedRows = await this.rdbStore.update(valuesBucket, predicates);
      console.info(`更新账单成功，影响行数: ${updatedRows}`);
      return updatedRows > 0;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`更新账单失败: ${error.message}`);
      return false;
    }
  }

  /**
   * 根据ID查询账单
   * @param id 账单ID
   * @returns Promise<BillRecord | null> 查询到的账单
   */
  async getBillById(id: number): Promise<BillRecord | null> {
    if (!this.rdbStore) {
      console.error('数据库未初始化');
      return null;
    }

    const predicates = new relationalStore.RdbPredicates(this.tableName);
    predicates.equalTo('BILL_ID', id);

    try {
      const resultSet = await this.rdbStore.query(predicates, ['BILL_ID', 'DATE', 'TYPE', 'CATEGORY', 'AMOUNT', 'REMARK']);
      if (resultSet.rowCount <= 0) {
        resultSet.close();
        return null;
      }

      resultSet.goToFirstRow();
      const bill: BillRecord = {
        id: resultSet.getDouble(resultSet.getColumnIndex('BILL_ID')),
        date: resultSet.getString(resultSet.getColumnIndex('DATE')),
        type: resultSet.getString(resultSet.getColumnIndex('TYPE')) as '收入' | '支出',
        category: resultSet.getString(resultSet.getColumnIndex('CATEGORY')),
        amount: resultSet.getDouble(resultSet.getColumnIndex('AMOUNT')),
        remark: resultSet.getString(resultSet.getColumnIndex('REMARK'))
      };

      resultSet.close();
      return bill;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`查询账单失败: ${error.message}`);
      return null;
    }
  }

  /**
   * 获取所有账单
   * @param options 可选的查询条件和排序
   * @returns Promise<BillRecord[]> 查询到的账单列表
   */
  async getAllBills(options?: QueryBillOptions): Promise<BillRecord[]> {
    if (!this.rdbStore) {
      console.error('数据库未初始化');
      return [];
    }

    const predicates = new relationalStore.RdbPredicates(this.tableName);
    
    // 添加查询条件
    if (options?.type) {
      predicates.equalTo('TYPE', options.type);
    }
    
    if (options?.startDate) {
      predicates.greaterThanOrEqualTo('DATE', options.startDate);
    }
    
    if (options?.endDate) {
      predicates.lessThanOrEqualTo('DATE', options.endDate);
    }
    
    // 添加排序
    if (options?.sortBy) {
      const field = options.sortBy === 'date' ? 'DATE' : 'AMOUNT';
      if (options.sortOrder === 'desc') {
        predicates.orderByDesc(field);
      } else {
        predicates.orderByAsc(field);
      }
    } else {
      // 默认按日期降序排列（最新的在前）
      predicates.orderByDesc('DATE');
    }

    try {
      const resultSet = await this.rdbStore.query(predicates, ['BILL_ID', 'DATE', 'TYPE', 'CATEGORY', 'AMOUNT', 'REMARK']);
      const bills: BillRecord[] = [];

      while (resultSet.goToNextRow()) {
        bills.push({
          id: resultSet.getDouble(resultSet.getColumnIndex('BILL_ID')),
          date: resultSet.getString(resultSet.getColumnIndex('DATE')),
          type: resultSet.getString(resultSet.getColumnIndex('TYPE')) as '收入' | '支出',
          category: resultSet.getString(resultSet.getColumnIndex('CATEGORY')),
          amount: resultSet.getDouble(resultSet.getColumnIndex('AMOUNT')),
          remark: resultSet.getString(resultSet.getColumnIndex('REMARK'))
        });
      }

      resultSet.close();
      return bills;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`查询所有账单失败: ${error.message}`);
      return [];
    }
  }

  /**
   * 获取统计数据
   * @param options 可选的统计条件
   * @returns Promise<StatisticsResult> 收入和支出总额
   */
  async getStatistics(options?: StatisticsOptions): Promise<StatisticsResult> {
    if (!this.rdbStore) {
      console.error('数据库未初始化');
      return { totalIncome: 0, totalExpense: 0 };
    }

    let totalIncome = 0;
    let totalExpense = 0;

    // 查询收入
    const incomePredicates = new relationalStore.RdbPredicates(this.tableName);
    incomePredicates.equalTo('TYPE', '收入');
    if (options?.startDate) {
      incomePredicates.greaterThanOrEqualTo('DATE', options.startDate);
    }
    if (options?.endDate) {
      incomePredicates.lessThanOrEqualTo('DATE', options.endDate);
    }

    // 查询支出
    const expensePredicates = new relationalStore.RdbPredicates(this.tableName);
    expensePredicates.equalTo('TYPE', '支出');
    if (options?.startDate) {
      expensePredicates.greaterThanOrEqualTo('DATE', options.startDate);
    }
    if (options?.endDate) {
      expensePredicates.lessThanOrEqualTo('DATE', options.endDate);
    }

    try {
      // 计算收入总额
      const incomeResultSet = await this.rdbStore.query(incomePredicates, ['AMOUNT']);
      while (incomeResultSet.goToNextRow()) {
        totalIncome += incomeResultSet.getDouble(incomeResultSet.getColumnIndex('AMOUNT'));
      }
      incomeResultSet.close();

      // 计算支出总额
      const expenseResultSet = await this.rdbStore.query(expensePredicates, ['AMOUNT']);
      while (expenseResultSet.goToNextRow()) {
        totalExpense += expenseResultSet.getDouble(expenseResultSet.getColumnIndex('AMOUNT'));
      }
      expenseResultSet.close();

      return { totalIncome, totalExpense };
    } catch (err) {
      const error = err as BusinessError;
      console.error(`获取统计数据失败: ${error.message}`);
      return { totalIncome: 0, totalExpense: 0 };
    }
  }

  /**
   * 按类别分组统计
   * @param type 收入或支出
   * @param options 可选的统计条件
   * @returns Promise<CategoryStatItem[]> 按类别分组的统计结果
   */
  async getCategoryStatistics(
    type: '收入' | '支出',
    options?: StatisticsOptions
  ): Promise<CategoryStatItem[]> {
    if (!this.rdbStore) {
      console.error('数据库未初始化');
      return [];
    }

    const predicates = new relationalStore.RdbPredicates(this.tableName);
    predicates.equalTo('TYPE', type);
    
    if (options?.startDate) {
      predicates.greaterThanOrEqualTo('DATE', options.startDate);
    }
    
    if (options?.endDate) {
      predicates.lessThanOrEqualTo('DATE', options.endDate);
    }

    try {
      const resultSet = await this.rdbStore.query(predicates, ['CATEGORY', 'AMOUNT']);
      
      // 手动分组统计
      const categoryMap = new Map<string, number>();
      
      while (resultSet.goToNextRow()) {
        const category = resultSet.getString(resultSet.getColumnIndex('CATEGORY'));
        const amount = resultSet.getDouble(resultSet.getColumnIndex('AMOUNT'));
        
        if (categoryMap.has(category)) {
          categoryMap.set(category, categoryMap.get(category)! + amount);
        } else {
          categoryMap.set(category, amount);
        }
      }
      
      resultSet.close();
      
      // 转换为数组并排序
      const result: CategoryStatItem[] = Array.from(categoryMap.entries()).map(([category, total]) => ({
        category,
        total
      }));
      
      // 按金额降序排序
      result.sort((a, b) => b.total - a.total);
      
      return result;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`获取类别统计数据失败: ${error.message}`);
      return [];
    }
  }
}

// 导出数据库服务单例
export const billDBService = new BillDBService(); 